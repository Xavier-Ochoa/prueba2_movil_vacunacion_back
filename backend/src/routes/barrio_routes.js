import { Router } from 'express'
import {
    listarBarrios,
    obtenerBarrio,
    crearBarrio,
    actualizarBarrio,
    eliminarBarrio,
    asignarBarrio,
    desasignarBarrio,
} from '../controllers/barrio_controller.js'
import {
    verificarTokenJWT,
    verificarCoordinadorCampana,
    verificarPasswordCambiada,
} from '../middlewares/JWT.js'

const router = Router()

// ── Rutas públicas (cualquier usuario autenticado puede consultar) ──────────────
router.get('/',     verificarTokenJWT, listarBarrios)
router.get('/:id',  verificarTokenJWT, obtenerBarrio)

// ── Rutas exclusivas de Coordinador de Campaña ─────────────────────────────────
router.use(verificarTokenJWT, verificarPasswordCambiada, verificarCoordinadorCampana)

router.post('/',                    crearBarrio)
router.put('/:id',                  actualizarBarrio)
router.delete('/:id',               eliminarBarrio)
router.post('/asignar',             asignarBarrio)
router.patch('/:id/desasignar',     desasignarBarrio)

export default router
