import Barrio from '../models/Barrio.js'
import Usuario from '../models/Usuario.js'

// ── LISTAR TODOS LOS BARRIOS ──────────────────────────────────────────────────
export const listarBarrios = async (req, res) => {
    try {
        const { sector, estado } = req.query

        const filtro = {}
        if (sector) filtro.sector = sector
        if (estado) filtro.estado = estado

        const barrios = await Barrio.find(filtro)
            .populate('coordinadorAsignado', 'nombre apellido email')
            .lean()

        res.status(200).json({ success: true, total: barrios.length, data: barrios })

    } catch (error) {
        console.error('❌ Error al listar barrios:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── OBTENER BARRIO POR ID ─────────────────────────────────────────────────────
export const obtenerBarrio = async (req, res) => {
    try {
        const barrio = await Barrio.findById(req.params.id)
            .populate('coordinadorAsignado', 'nombre apellido email')
            .lean()

        if (!barrio) {
            return res.status(404).json({ msg: 'Barrio no encontrado' })
        }

        res.status(200).json({ success: true, data: barrio })

    } catch (error) {
        console.error('❌ Error al obtener barrio:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── CREAR BARRIO ──────────────────────────────────────────────────────────────
export const crearBarrio = async (req, res) => {
    try {
        const { nombre, sector } = req.body

        if (!nombre || !sector) {
            return res.status(400).json({ msg: 'El nombre y el sector son obligatorios' })
        }

        const existe = await Barrio.findOne({ nombre: nombre.trim() })
        if (existe) {
            return res.status(400).json({ msg: 'Ya existe un barrio con ese nombre' })
        }

        const barrio = new Barrio({ nombre: nombre.trim(), sector })
        await barrio.save()

        res.status(201).json({ success: true, msg: 'Barrio creado correctamente', data: barrio })

    } catch (error) {
        console.error('❌ Error al crear barrio:', error.message)
        if (error.name === 'ValidationError') {
            const errores = Object.values(error.errors).map(e => e.message)
            return res.status(400).json({ msg: 'Error de validación', errors: errores })
        }
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── ACTUALIZAR BARRIO ─────────────────────────────────────────────────────────
export const actualizarBarrio = async (req, res) => {
    try {
        const { nombre, sector, estado } = req.body

        const barrio = await Barrio.findById(req.params.id)
        if (!barrio) {
            return res.status(404).json({ msg: 'Barrio no encontrado' })
        }

        // Si se está pasando el barrio a 'inactivo', aplicamos el mismo
        // criterio que al eliminar: no se puede dejar inactivo un barrio
        // que todavía tiene vacunadores ACTIVOS trabajando en él, porque
        // quedarían operando en un barrio que ya no está disponible.
        const seVaAInactivar = estado === 'inactivo' && barrio.estado !== 'inactivo'

        if (seVaAInactivar) {
            const vacunadoresAfectados = await Usuario.find({
                rol:              'vacunador',
                estado:           'activo',
                barriosAsignados: barrio._id,
            }).select('+estado nombre apellido')

            if (vacunadoresAfectados.length > 0) {
                return res.status(409).json({
                    msg: 'No se puede inactivar este barrio porque tiene vacunadores activos asignados. ' +
                         'Reasigna o desactiva primero a esos vacunadores.',
                    vacunadoresAfectados: vacunadoresAfectados.map(v => ({
                        _id:    v._id,
                        nombre: `${v.nombre} ${v.apellido}`,
                    })),
                })
            }
        }

        if (nombre) barrio.nombre = nombre.trim()
        if (sector) barrio.sector = sector
        if (estado) barrio.estado = estado

        await barrio.save()

        res.status(200).json({ success: true, msg: 'Barrio actualizado correctamente', data: barrio })

    } catch (error) {
        console.error('❌ Error al actualizar barrio:', error.message)
        if (error.name === 'ValidationError') {
            const errores = Object.values(error.errors).map(e => e.message)
            return res.status(400).json({ msg: 'Error de validación', errors: errores })
        }
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── ELIMINAR BARRIO ───────────────────────────────────────────────────────────
export const eliminarBarrio = async (req, res) => {
    try {
        const barrio = await Barrio.findById(req.params.id)
        if (!barrio) {
            return res.status(404).json({ msg: 'Barrio no encontrado' })
        }

        // No se puede eliminar un barrio si tiene vacunadores ACTIVOS
        // asignados (los dejaría con una referencia a un barrio inexistente).
        const vacunadoresAfectados = await Usuario.find({
            rol:              'vacunador',
            estado:           'activo',
            barriosAsignados: barrio._id,
        }).select('+estado nombre apellido')

        if (vacunadoresAfectados.length > 0) {
            return res.status(409).json({
                msg: 'No se puede eliminar este barrio porque tiene vacunadores activos asignados. ' +
                     'Reasigna o desactiva primero a esos vacunadores.',
                vacunadoresAfectados: vacunadoresAfectados.map(v => ({
                    _id:    v._id,
                    nombre: `${v.nombre} ${v.apellido}`,
                })),
            })
        }

        // Si tiene coordinador asignado, limpiar la referencia en el usuario
        if (barrio.coordinadorAsignado) {
            await Usuario.findByIdAndUpdate(barrio.coordinadorAsignado, {
                $pull: { barriosAsignados: barrio._id },
            })
        }

        await barrio.deleteOne()

        res.status(200).json({ success: true, msg: 'Barrio eliminado correctamente' })

    } catch (error) {
        console.error('❌ Error al eliminar barrio:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── ASIGNAR BARRIO A COORDINADOR DE BRIGADA ───────────────────────────────────
export const asignarBarrio = async (req, res) => {
    try {
        const { barrioId, coordinadorId } = req.body

        if (!barrioId || !coordinadorId) {
            return res.status(400).json({ msg: 'barrioId y coordinadorId son obligatorios' })
        }

        const barrio = await Barrio.findById(barrioId)
        if (!barrio) {
            return res.status(404).json({ msg: 'Barrio no encontrado' })
        }

        const coordinador = await Usuario.findById(coordinadorId)
        if (!coordinador) {
            return res.status(404).json({ msg: 'Coordinador no encontrado' })
        }

        if (coordinador.rol !== 'coordinador_brigada') {
            return res.status(400).json({ msg: 'El usuario debe tener rol de Coordinador de Brigada' })
        }

        // Si el barrio ya tenía otro coordinador, quitarle la asignación
        if (barrio.coordinadorAsignado && barrio.coordinadorAsignado.toString() !== coordinadorId) {
            await Usuario.findByIdAndUpdate(barrio.coordinadorAsignado, {
                $pull: { barriosAsignados: barrio._id },
            })
        }

        // Asignar el barrio al coordinador
        barrio.coordinadorAsignado = coordinadorId
        await barrio.save()

        // Agregar el barrio en el array del coordinador (si no está ya)
        await Usuario.findByIdAndUpdate(coordinadorId, {
            $addToSet: { barriosAsignados: barrio._id },
        })

        const barrioActualizado = await Barrio.findById(barrioId)
            .populate('coordinadorAsignado', 'nombre apellido email')
            .lean()

        res.status(200).json({
            success: true,
            msg: `Barrio "${barrio.nombre}" asignado correctamente`,
            data: barrioActualizado,
        })

    } catch (error) {
        console.error('❌ Error al asignar barrio:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}

// ── DESASIGNAR BARRIO ─────────────────────────────────────────────────────────
export const desasignarBarrio = async (req, res) => {
    try {
        const { id } = req.params

        const barrio = await Barrio.findById(id)
        if (!barrio) {
            return res.status(404).json({ msg: 'Barrio no encontrado' })
        }

        if (!barrio.coordinadorAsignado) {
            return res.status(400).json({ msg: 'El barrio no tiene coordinador asignado' })
        }

        // Quitar el barrio del array del coordinador
        await Usuario.findByIdAndUpdate(barrio.coordinadorAsignado, {
            $pull: { barriosAsignados: barrio._id },
        })

        barrio.coordinadorAsignado = null
        await barrio.save()

        res.status(200).json({ success: true, msg: 'Barrio desasignado correctamente' })

    } catch (error) {
        console.error('❌ Error al desasignar barrio:', error.message)
        res.status(500).json({ success: false, msg: 'Error interno del servidor', error: error.message })
    }
}
