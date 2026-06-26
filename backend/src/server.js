import express from 'express'
import cors from 'cors'

import authRoutes       from './routes/auth_routes.js'
import usuarioRoutes    from './routes/usuario_routes.js'
import barrioRoutes     from './routes/barrio_routes.js'
import vacunacionRoutes from './routes/vacunacion_routes.js'

const app = express()

// ── Body parsers ──────────────────────────────
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// ── CORS — acepta requests de Flutter (móvil) ─
app.use(cors({
    origin: '*',   // Flutter mobile no tiene origen fijo; ajustar en prod si se quiere restringir
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    credentials: true,
}))

// ── Ruta raíz ─────────────────────────────────
app.get('/', (req, res) => {
    res.json({ msg: 'API Sistema de Vacunación - Sprint 2 ✅', version: '2.0.0' })
})

// ── Rutas ─────────────────────────────────────
app.use('/api/auth',        authRoutes)
app.use('/api/usuarios',    usuarioRoutes)
app.use('/api/barrios',     barrioRoutes)
app.use('/api/vacunaciones', vacunacionRoutes)

// ── 404 ───────────────────────────────────────
app.use((req, res) => {
    res.status(404).json({ success: false, msg: 'Endpoint no encontrado' })
})

// ── Error global ──────────────────────────────
app.use((err, req, res, next) => {
    console.error('❌ Error:', err)
    // Error de multer (imagen)
    if (err.message && err.message.includes('Solo se permiten')) {
        return res.status(400).json({ success: false, msg: err.message })
    }
    if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({ success: false, msg: 'La imagen no puede superar 5MB' })
    }
    res.status(500).json({
        success: false,
        msg: 'Error interno del servidor',
        error: process.env.NODE_ENV === 'development' ? err.message : undefined,
    })
})

export default app
