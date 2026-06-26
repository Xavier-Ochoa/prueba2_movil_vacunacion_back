/**
 * Script para crear el Coordinador de Campaña inicial.
 *
 * Ejecutar UNA SOLA VEZ:
 *   node src/seeders/crear_coordinador_campana.js
 *
 * Edita los datos de abajo antes de ejecutar.
 */

import dotenv from 'dotenv'
dotenv.config()

import mongoose from 'mongoose'
import bcrypt from 'bcryptjs'
import Usuario from '../models/Usuario.js'

// ── EDITAR ESTOS DATOS ─────────────────────────────────────────────────────────
const DATOS = {
    nombre:   'Admin',
    apellido: 'Campaña',
    cedula:   '1700000001',
    email:    'coordinador@vacunacion.gob.ec',
    password: 'Admin1234!',      // ← cambia por una contraseña segura
    telefono: '0999999999',
}
// ──────────────────────────────────────────────────────────────────────────────

const crear = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI)
        console.log('✅ Conectado a MongoDB')

        const existe = await Usuario.findOne({ email: DATOS.email.toLowerCase() })
        if (existe) {
            console.log('⚠️  Ya existe un usuario con ese correo.')
            return
        }

        const salt    = await bcrypt.genSalt(10)
        const hashed  = await bcrypt.hash(DATOS.password, salt)

        const coordinador = new Usuario({
            nombre:           DATOS.nombre,
            apellido:         DATOS.apellido,
            cedula:           DATOS.cedula,
            email:            DATOS.email.toLowerCase(),
            telefono:         DATOS.telefono,
            password:         hashed,
            rol:              'coordinador_campana',
            passwordCambiada: true,    // no forzar cambio en primer login
            estado:           'activo',
        })

        await coordinador.save()

        console.log('✅ Coordinador de Campaña creado exitosamente')
        console.log(`   Email:    ${DATOS.email}`)
        console.log(`   Password: ${DATOS.password}`)
        console.log(`   ID:       ${coordinador._id}`)

    } catch (error) {
        console.error('❌ Error:', error.message)
    } finally {
        await mongoose.disconnect()
        console.log('🔌 Desconectado de MongoDB')
    }
}

crear()
