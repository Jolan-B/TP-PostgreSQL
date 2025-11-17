const express = require('express');
const pool = require('./database/db');
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// MIDDLEWARE
app.use(express.json());

// ROUTES
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);

app.get('/api/health', async (req, res) => {
    try {
        const result = await pool.query('SELECT NOW()');
        res.json({
            status: 'OK',
            database: 'Connected',
            timestamp: result.rows[0].now
        });
    } catch (error) {
        console.error('Error :', error);
        res.status(500).json({
            status: 'ERROR',
            database: 'Disconnected',
            error: error.message
        });
    }
});

app.get('/', (req, res) => {
    res.json({
        message: 'API Gestion Utilisateurs',
        version: '1.0.0',
        endpoints: {
            health: 'GET /api/health',
            auth: {
                register: 'POST /api/auth/register',
                login: 'POST /api/auth/login',
                logout: 'POST /api/auth/logout',
                profile: 'GET /api/auth/profile',
                logs: 'GET /api/auth/logs'
            },
            users: {
                list: 'GET /api/users',
                get: 'GET /api/users/:id',
                update: 'PUT /api/users/:id',
                delete: 'DELETE /api/users/:id',
                permissions: 'GET /api/users/:id/permissions'
            }
        }
    });
});

app.listen(PORT, () => {
    console.log(`PORT : ${PORT}`);
});
