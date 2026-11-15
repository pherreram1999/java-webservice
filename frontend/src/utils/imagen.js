/*
  Reduce una imagen elegida por el usuario y la devuelve como base64 JPEG (sin el prefijo "data:").
  Las fotos de un celular pesan varios MB; reducirlas evita JSON enormes al buscar artículos.
*/
export function reduceImagen(archivo, maxLado = 1024, calidad = 0.85) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(archivo);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      const escala = Math.min(1, maxLado / Math.max(img.naturalWidth, img.naturalHeight));
      const canvas = document.createElement("canvas");
      canvas.width = Math.max(1, Math.round(img.naturalWidth * escala));
      canvas.height = Math.max(1, Math.round(img.naturalHeight * escala));
      const ctx = canvas.getContext("2d");
      ctx.fillStyle = "#ffffff"; // los PNG con transparencia se vuelven negros en JPEG si no hay fondo
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      resolve(canvas.toDataURL("image/jpeg", calidad).split(",")[1]);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("No se pudo leer la imagen"));
    };
    img.src = url;
  });
}
