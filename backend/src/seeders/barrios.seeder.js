/**
 * Seeder — 25 barrios de Quito
 *
 * Ejecutar con:  npm run seed
 *
 * Sectores usados:
 *   Norte        → Barrios del norte de Quito
 *   Centro Norte → La Mariscal, Iñaquito, Rumipamba
 *   Centro       → Centro Histórico y alrededores
 *   Sur          → Barrios del sur de Quito
 *   Valles       → Cumbayá, Tumbaco, Los Chillos
 */

import dotenv from 'dotenv'
dotenv.config()

import mongoose from 'mongoose'
import Barrio from '../models/Barrio.js'

const BARRIOS = [
    // ── NORTE ──────────────────────────────────────────────────────────────
    { nombre: 'Cotocollao',          sector: 'Norte'        },
    { nombre: 'Ponceano',            sector: 'Norte'        },
    { nombre: 'Comité del Pueblo',   sector: 'Norte'        },
    { nombre: 'El Condado',          sector: 'Norte'        },
    { nombre: 'Carcelén',            sector: 'Norte'        },

    // ── CENTRO NORTE ───────────────────────────────────────────────────────
    { nombre: 'La Mariscal',         sector: 'Centro Norte' },
    { nombre: 'Iñaquito',            sector: 'Centro Norte' },
    { nombre: 'Rumipamba',           sector: 'Centro Norte' },
    { nombre: 'Belisario Quevedo',   sector: 'Centro Norte' },
    { nombre: 'La Floresta',         sector: 'Centro Norte' },

    // ── CENTRO ─────────────────────────────────────────────────────────────
    { nombre: 'Centro Histórico',    sector: 'Centro'       },
    { nombre: 'La Tola',             sector: 'Centro'       },
    { nombre: 'San Juan',            sector: 'Centro'       },
    { nombre: 'La Vicentina',        sector: 'Centro'       },
    { nombre: 'Itchimbía',           sector: 'Centro'       },

    // ── SUR ────────────────────────────────────────────────────────────────
    { nombre: 'Solanda',             sector: 'Sur'          },
    { nombre: 'La Magdalena',        sector: 'Sur'          },
    { nombre: 'Chillogallo',         sector: 'Sur'          },
    { nombre: 'Quitumbe',            sector: 'Sur'          },
    { nombre: 'Guamaní',             sector: 'Sur'          },

    // ── VALLES ─────────────────────────────────────────────────────────────
    { nombre: 'Cumbayá',             sector: 'Valles'       },
    { nombre: 'Tumbaco',             sector: 'Valles'       },
    { nombre: 'San Rafael',          sector: 'Valles'       },
    { nombre: 'Sangolquí',           sector: 'Valles'       },
    { nombre: 'La Armenia',          sector: 'Valles'       },
]

const seed = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI)
        console.log('✅ Conectado a MongoDB')

        // Eliminar barrios existentes para evitar duplicados
        await Barrio.deleteMany({})
        console.log('🗑️  Barrios anteriores eliminados')

        const insertados = await Barrio.insertMany(BARRIOS)
        console.log(`✅ ${insertados.length} barrios insertados correctamente:`)

        insertados.forEach(b => {
            console.log(`   • ${b.nombre.padEnd(22)} → ${b.sector}`)
        })

    } catch (error) {
        console.error('❌ Error en el seeder:', error.message)
    } finally {
        await mongoose.disconnect()
        console.log('\n🔌 Desconectado de MongoDB')
    }
}

seed()
