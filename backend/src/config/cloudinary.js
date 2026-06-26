import { v2 as cloudinary } from 'cloudinary'
import { CloudinaryStorage } from 'multer-storage-cloudinary'
import multer from 'multer'

// Configurar Cloudinary con variables de entorno
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key:    process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
})

// Storage para multer → sube directo a Cloudinary
const storage = new CloudinaryStorage({
    cloudinary,
    params: {
        folder:         'vacunacion-mascotas',
        allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
        transformation: [{ width: 800, height: 800, crop: 'limit', quality: 'auto' }],
    },
})

// Middleware multer con límite de 5MB
export const uploadImagen = multer({
    storage,
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
