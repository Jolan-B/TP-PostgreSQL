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