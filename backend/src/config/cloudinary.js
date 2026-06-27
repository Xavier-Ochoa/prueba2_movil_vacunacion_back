import { v2 as cloudinary } from 'cloudinary'
import multer from 'multer'

// Configurar Cloudinary con variables de entorno
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key:    process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
})

// multer guarda el archivo en memoria (Buffer) — sin dependencia de multer-storage-cloudinary
export const uploadImagen = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        const tiposPermitidos = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
        if (tiposPermitidos.includes(file.mimetype)) {
            cb(null, true)
        } else {
            cb(new Error('Solo se permiten imágenes JPG, PNG o WEBP'), false)
        }
    },
})

/**
 * Sube el buffer de req.file a Cloudinary y devuelve { secure_url, public_id }.
 * Llámalo en el controlador después de uploadImagen.single('imagen').
 *
 * Ejemplo:
 *   const { secure_url, public_id } = await subirImagenBuffer(req.file.buffer)
 */
export const subirImagenBuffer = (buffer, opciones = {}) => {
    return new Promise((resolve, reject) => {
        const defaults = {
            folder:         'vacunacion-mascotas',
            transformation: [{ width: 800, height: 800, crop: 'limit', quality: 'auto' }],
            allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
        }
        const stream = cloudinary.uploader.upload_stream(
            { ...defaults, ...opciones },
            (error, result) => {
                if (error) return reject(error)
                resolve({ secure_url: result.secure_url, public_id: result.public_id })
            }
        )
        stream.end(buffer)
    })
}

// Eliminar imagen de Cloudinary por su publicId
export const eliminarImagenCloudinary = async (publicId) => {
    if (!publicId) return
    try {
        await cloudinary.uploader.destroy(publicId)
    } catch (error) {
        console.error('⚠️ Error al eliminar imagen de Cloudinary:', error.message)
    }
}

export default cloudinary
