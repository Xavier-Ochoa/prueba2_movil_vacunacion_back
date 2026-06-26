import { Router } from 'express'
import {
    crearVacunacion,
    listarVacunaciones,
    obtenerVacunacion,
    editarVacunacion,
    eliminarVacunacion,
    obtenerEstadisticas,
} from '../controllers/vacunacion_controller.js'
import {
    verificarTokenJWT,
    verificarPasswordCambiada,
} from '../middlewares/JWT.js'
import { uploadImagen } from '../config/cloudinary.js'

const router = Router()

// Todas las rutas requieren token válido y contraseña cambiada
router.use(verificarTokenJWT, verificarPasswordCambiada)

// ── Dashboard ──────────────────────────────────────────────────────────────────
router.get('/estadisticas', obtenerEstadisticas)

// ── CRUD ───────────────────────────────────────────────────────────────────────
router.post(
    '/',
    uploadImagen.single('imagen'), // Campo 'imagen' en el multipart/form-data
    crearVacunacion
)

router.get('/',     listarVacunaciones)
router.get('/:id',  obtenerVacunacion)

router.put(
    '/:id',
    uploadImagen.single('imagen'),
    editarVacunacion
)

router.delete('/:id', eliminarVacunacion)

export default router
