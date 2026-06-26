import mongoose from 'mongoose'

export const conectarDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI)
        console.log('✅ Conexión a MongoDB establecida')
    } catch (error) {
        console.error('❌ Error al conectar MongoDB:', error.message)
        process.exit(1)
    }
}
