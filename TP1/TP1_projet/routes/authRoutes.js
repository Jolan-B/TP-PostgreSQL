const express = require('express');
const router = express.Router();
const pool = require('../database/db');
const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
const { requireAuth } = require('../middleware/auth');

// Inscription
router.post('/register', async (req, res) => {
    const { email, password, nom, prenom } = req.body;

    // 1. Validation
    if (!email || !password) {
        return res.status(400).json({ error: 'Email et mot de passe requis' });
    }

    const client = await pool.connect();

    try {
        await client.query('BEGIN');

        // si email existe
        const checkUser = await client.query(
            'SELECT id FROM utilisateurs WHERE email = $1',
            [email]
        );

        if (checkUser.rows.length > 0) {
            await client.query('ROLLBACK');
            return res.status(409).json({ error: 'Email déjà utilisé' });
        }

        // hashage du mdp
        const passwordHash = await bcrypt.hash(password, 10);

        // on creée l'utilisateur
        const result = await client.query(
            `INSERT INTO utilisateurs (email, password_hash, nom, prenom)
             VALUES ($1, $2, $3, $4)
             RETURNING id, email, nom, prenom, date_creation`,
            [email, passwordHash, nom, prenom]
        );

        const newUser = result.rows[0];

        await client.query(
            `INSERT INTO utilisateur_roles (utilisateur_id, role_id)
             SELECT $1, id FROM roles WHERE nom = 'user'`,
            [newUser.id]
        );

        await client.query('COMMIT');

        res.status(201).json({
            message: 'Utilisateur créé avec succès',
            user: newUser
        });

    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Erreur création utilisateur:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    } finally {
        client.release();
    }
});

// Connexion
router.post('/login', async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email et mot de passe requis' });
    }

    const client = await pool.connect();
    try {
        await client.query('BEGIN');

        const userResult = await client.query(
            `SELECT id, email, password_hash, nom, prenom, actif
             FROM utilisateurs WHERE email = $1`,
            [email]
        );

        // echec log
        if (userResult.rows.length === 0) {
            await client.query(
                `INSERT INTO logs_connexion (utilisateur_id, email_tentative, succes, message)
                 VALUES (NULL, $1, false, 'Email inexistant')`,
                [email]
            );
            await client.query('COMMIT');
            return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
        }

        const user = userResult.rows[0];

        if (!user.actif) {
            await client.query(
                `INSERT INTO logs_connexion (utilisateur_id, email_tentative, succes, message)
                 VALUES ($1, $2, false, 'Compte désactivé')`,
                [user.id, email]
            );
            await client.query('COMMIT');
            return res.status(403).json({ error: 'Compte désactivé' });
        }

        // verification mdp
        const passwordMatch = await bcrypt.compare(password, user.password_hash);

        if (!passwordMatch) {
            await client.query(
                `INSERT INTO logs_connexion (utilisateur_id, email_tentative, succes, message)
                 VALUES ($1, $2, false, 'Mot de passe incorrect')`,
                [user.id, email]
            );
            await client.query('COMMIT');
            return res.status(401).json({ error: 'Email ou mot de passe incorrect' });
        }

        // Création token
        const token = uuidv4();
        const expiresAt = new Date();
        expiresAt.setHours(expiresAt.getHours() + 24);

        // Création session
        await client.query(
            `INSERT INTO sessions (utilisateur_id, token, date_expiration)
             VALUES ($1, $2, $3)`,
            [user.id, token, expiresAt]
        );

        await client.query(
            `INSERT INTO logs_connexion (utilisateur_id, email_tentative, succes, message)
             VALUES ($1, $2, true, 'Connexion réussie')`,
            [user.id, email]
        );

        await client.query('COMMIT');

        res.json({
            message: 'Connexion réussie',
            token: token,
            user: {
                id: user.id,
                email: user.email,
                nom: user.nom,
                prenom: user.prenom
            },
            expiresAt: expiresAt
        });

    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Erreur :', error);
        res.status(500).json({ error: 'Erreur serveur' });
    } finally {
        client.release();
    }
});

// Déconnexion
router.post('/logout', requireAuth, async (req, res) => {
    const token = req.headers['authorization'];

    try {
        await pool.query(
            'UPDATE sessions SET actif = false WHERE token = $1',
            [token]
        );

        await pool.query(
            `INSERT INTO logs_connexion (utilisateur_id, email_tentative, succes, message)
             VALUES ($1, $2, true, 'Déconnexion')`,
            [req.user.utilisateur_id, req.user.email]
        );

        res.json({ message: 'Déconnexion réussie' });

    } catch (error) {
        console.error('Erreur logout:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// Profil utilisateur GET
router.get('/profile', requireAuth, async (req, res) => {
    try {
        // Récupérer l'utilisateur avec ses rôles
        const result = await pool.query(
            `SELECT 
                u.id,
                u.email,
                u.nom,
                u.prenom,
                u.actif,
                u.date_creation,
                COALESCE(array_agg(r.nom) FILTER (WHERE r.nom IS NOT NULL), ARRAY[]::VARCHAR[]) AS roles
            FROM utilisateurs u
            LEFT JOIN utilisateur_roles ur ON u.id = ur.utilisateur_id
            LEFT JOIN roles r ON ur.role_id = r.id
            WHERE u.id = $1
            GROUP BY u.id, u.email, u.nom, u.prenom, u.actif, u.date_creation`,
            [req.user.utilisateur_id]
        );

        res.json({ user: result.rows[0] });

    } catch (error) {
        console.error('Erreur profil:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

// Historique des connexions GET

router.get('/logs', requireAuth, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT * FROM logs_connexion
             WHERE utilisateur_id = $1
             ORDER BY date_heure DESC
             LIMIT 50`,
            [req.user.utilisateur_id]
        );

        res.json({ logs: result.rows });

    } catch (error) {
        console.error('Erreur logs:', error);
        res.status(500).json({ error: 'Erreur serveur' });
    }
});

module.exports = router;
