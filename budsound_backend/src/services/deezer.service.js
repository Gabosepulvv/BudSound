const DEEZER_SEARCH_URL = 'https://api.deezer.com/search';
const DEEZER_TRACK_URL = 'https://api.deezer.com/track';

// Ni iTunes ni nuestra propia base de datos tienen el BPM de una canción —
// Deezer sí lo expone, pero solo en el detalle de /track/:id (el buscador
// /search no lo trae), así que hace falta encadenar dos requests. Es "mejor
// esfuerzo": si Deezer no tiene la canción, no la analizó (bpm = 0), o no
// responde a tiempo, se devuelve null y la cola del DJ simplemente no
// muestra el dato — nunca bloquea ni retrasa de forma relevante pedir una
// canción.
async function buscarBpm({ titulo, artista }) {
  try {
    // La sintaxis de filtros de Deezer (`track:"..." artist:"..."` juntos)
    // devuelve 0 resultados en la práctica aunque cada filtro funcione por
    // separado — se probó a mano contra la API real. Una búsqueda de texto
    // simple, en cambio, sí funciona y Deezer ordena por relevancia/
    // popularidad, así que el primer resultado ya suele ser la versión
    // original en vez de un remix o cover.
    const params = new URLSearchParams({
      q: `${artista} ${titulo}`,
      limit: '1',
    });
    const resBusqueda = await fetch(`${DEEZER_SEARCH_URL}?${params.toString()}`, {
      signal: AbortSignal.timeout(3000),
    });
    if (!resBusqueda.ok) return null;

    const dataBusqueda = await resBusqueda.json();
    const trackId = dataBusqueda?.data?.[0]?.id;
    if (!trackId) return null;

    const resTrack = await fetch(`${DEEZER_TRACK_URL}/${trackId}`, {
      signal: AbortSignal.timeout(3000),
    });
    if (!resTrack.ok) return null;

    const dataTrack = await resTrack.json();
    const bpm = Math.round(Number(dataTrack?.bpm) || 0);
    return bpm > 0 ? bpm : null;
  } catch (_) {
    return null;
  }
}

module.exports = { buscarBpm };
