-- Se connecter à PostgreSQL
-- sudo -u postgres psql

-- Créer la base de données
-- CREATE DATABASE gestion_utilisateurs;

-- Se connecter à la base
-- \c gestion_utilisateurs

-- TASK 1

CREATE TABLE utilisateurs (
 id SERIAL PRIMARY KEY,
 email VARCHAR(255) UNIQUE NOT NULL,
 password_hash VARCHAR(255) NOT NULL,
 nom VARCHAR(100),
 prenom VARCHAR(100),
 actif BOOLEAN DEFAULT true,
 date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT email_format CHECK (email ~* '^[a-zA-Z0-9.!#$%&''*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$' )
)
-- Index pour recherche rapide
CREATE INDEX idx_utilisateurs_email ON utilisateurs(email);
CREATE INDEX idx_utilisateurs_actif ON utilisateurs(actif);

-- TASK 2

CREATE TABLE roles (
 id SERIAL PRIMARY KEY, 
 nom VARCHAR(255) UNIQUE NOT NULL, 
 description TEXT,
 date_creation TIMESTAMP
);

CREATE TABLE permissions (
 id SERIAL PRIMARY KEY, 
 nom VARCHAR(255) UNIQUE NOT NULL, 
 ressource VARCHAR(100) NOT NULL, 
 action VARCHAR(50) NOT NULL, 
 description TEXT,
 CONSTRAINT unique_ressource_action UNIQUE(ressource, action)
);

-- TASK 3

-- Table association utilisateur_roles
CREATE TABLE utilisateur_roles (
 utilisateur_id INT NOT NULL,
 role_id INT NOT NULL,
 date_assignation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT fk_utilisateur-id FOREIGN KEY (utilisateur_id) REFERENCES utilisateur(id) ON DELETE CASCADE,
 CONSTRAINT fk_role-id FOREIGN KEY (role_id) REFERENCES role(id) ON DELETE CASCADE,
 PRIMARY KEY(utilisateur_id,role_id)
);
-- Table association role_permissions
CREATE TABLE role_permissions (
 role_id INT NOT NULL
 permission_id INT NOT NULL
 CONSTRAINT fk_permission-id FOREIGN KEY (permission_id) REFERENCES permission(id) ON DELETE CASCADE,
 CONSTRAINT fk_role-id FOREIGN KEY (role_id) REFERENCES role(id) ON DELETE CASCADE,
 PRIMARY KEY(role_id,permission_id)
);

-- TASK 4

CREATE TABLE sessions (
 id SERIAL PRIMAREY KEY,
 utilisateur_id INT NOT NULL, 
 token VARCHAR(255) UNIQUE NOT NULL,
 date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
 date_expiration TIMESTAMP NOT NULL, 
 actif BOOLEAN DEFAULT true,
 CONSTRAINT fk_utilisateur-id FOREIGN KEY (utilisateur_id) REFERENCES utilisateur(id) ON DELETE CASCADE
);

CREATE TABLE logs_connexion (
 id  SERIAL PRIMAREY KEY,
 utilisateur_id INT, 
 email_tentative VARCAHR(255) NOT NULL,
 date_heure TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 adresse_ip VARCHAR(45),
 user_agent TEXT, 
 succes BOOLEAN NOT NULL, 
 message TEXT,
 CONSTRAINT fk_utilisateur-id FOREIGN KEY (utilisateur_id) REFERENCES utilisateur(id) ON DELETE SET NULL
);

-- TASK 5

-- Insérer des rôles
INSERT INTO roles (nom, description) VALUES
 ('admin', 'Administrateur avec tous les droits'),
 ('moderator', 'Modérateur de contenu'),
 ('user', 'Utilisateur standard');

-- Insérer des permissions
INSERT INTO permissions (nom, ressource, action, description) VALUES
 ('read_users', 'users', 'read', 'Lire les utilisateurs'),
 ('write_users', 'users', 'write', 'Créer/modifier des utilisateurs'),
 ('delete_users', 'users', 'delete', 'Supprimer des utilisateurs'),
 ('read_posts', 'posts', 'read', 'Lire les posts'),
 ('write_posts', 'posts', 'write', 'Créer/modifier des posts'),
 ('delete_posts', 'posts', 'delete', 'Supprimer des posts');

-- À VOUS: Associez les permissions aux rôles

-- Admin: toutes les permissions
-- Moderator: read_users, read_posts, write_posts, delete_posts
-- User: read_users, read_posts, write_posts

INSERT INTO role_permissions (role_id,permission_id) VALUES
(SELECT id FROM roles WHERE nom='admin',SELECT id FROM permission),
(SELECT id FROM roles WHERE nom='moderator',SELECT id FROM permission WHERE nom = 'read_users' || nom = 'read_posts' || nom='write_posts' || nom='delete_posts'),
(SELECT id FROM roles WHERE nom='user',SELECT id FROM permission WHERE nom = 'read_posts' || nom='write_posts');

-- TASK 6

CREATE OR REPLACE FUNCTION utilisateur_a_permission(
    p_utilisateur_id INT,
    p_ressource VARCHAR,
    p_action VARCHAR
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM utilisateurs u
        INNER JOIN utilisateur_roles ur ON u.id = ur.utilisateur_id
        INNER JOIN role_permissions rp ON ur.role_id = rp.role_id
        INNER JOIN permissions p ON rp.permission_id = p.id
        WHERE u.id = p_utilisateur_id
          AND u.actif = TRUE
          AND p.ressource = p_ressource
          AND p.action = p_action
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION est_token_valide(p_token VARCHAR)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM sessions s
        INNER JOIN utilisateurs u ON s.utilisateur_id = u.id
        WHERE s.token = p_token
          AND s.actif = TRUE
          AND s.date_expiration > CURRENT_TIMESTAMP
          AND u.actif = TRUE
    );
END;
$$ LANGUAGE plpgsql;

-- TASK 7

SELECT
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
WHERE u.id = 1
GROUP BY u.id, u.email, u.nom, u.prenom, u.actif, u.date_creation;

-- TASK 8

SELECT DISTINCT
    u.id AS utilisateur_id,
    u.email,
    p.nom AS permission,
    p.ressource,
    p.action
FROM utilisateurs u
INNER JOIN utilisateur_roles ur ON u.id = ur.utilisateur_id
INNER JOIN role_permissions rp ON ur.role_id = rp.role_id
INNER JOIN permissions p ON rp.permission_id = p.id
WHERE u.id = 1
ORDER BY p.ressource, p.action;

-- TASK 9

SELECT
    r.nom AS role,
    COUNT(DISTINCT ur.utilisateur_id) AS nombre_utilisateurs
FROM roles r
LEFT JOIN utilisateur_roles ur ON r.id = ur.role_id
GROUP BY r.id, r.nom
ORDER BY nombre_utilisateurs DESC;

-- TASK 10

SELECT
    u.id,
    u.email,
    array_agg(r.nom) AS roles
FROM utilisateurs u
INNER JOIN utilisateur_roles ur ON u.id = ur.utilisateur_id
INNER JOIN roles r ON ur.role_id = r.id
WHERE r.nom IN ('admin', 'moderator')
GROUP BY u.id, u.email
HAVING COUNT(DISTINCT r.nom) = 2;

-- TASK 11

SELECT
    DATE(date_heure) AS jour,
    COUNT(*) AS tentatives_echouees
FROM logs_connexion
WHERE succes = FALSE
  AND date_heure >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY DATE(date_heure)
ORDER BY jour DESC;