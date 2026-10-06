const ITUNES_SEARCH_URL = 'https://itunes.apple.com/search';
const ITUNES_TOP_SONGS_URL = 'https://itunes.apple.com/cl/rss/topsongs';

// Solo metadatos (título, artista, portada) — nunca streaming. La
// reproducción real ocurre en el equipo del DJ, fuera de la app.
async function buscarCanciones(term, { limit = 15 } = {}) {
  const params = new URLSearchParams({
    term,
    media: 'music',
    entity: 'song',
    limit: String(limit),
  });

  const response = await fetch(`${ITUNES_SEARCH_URL}?${params.toString()}`);
  if (!response.ok) {
    throw new Error('No se pudo consultar iTunes Search API.');
  }

  const data = await response.json();
  return (data.results || []).map((track) => ({
    itunesTrackId: track.trackId,
    titulo: track.trackName,
    artista: track.artistName,
    artworkUrl: track.artworkUrl100,
    previewUrl: track.previewUrl,
  }));
}

// Feed RSS de "Top Songs" de Chile (gratis, sin key, es una API distinta de
// Search) — para que la búsqueda no arranque vacía: el participante ve
// canciones reales y populares de entrada, en vez de una pantalla en
// blanco hasta que escriba algo.
async function topCanciones({ limit = 20 } = {}) {
  const response = await fetch(`${ITUNES_TOP_SONGS_URL}/limit=${limit}/json`);
  if (!response.ok) {
    throw new Error('No se pudo consultar el top de iTunes.');
  }

  const data = await response.json();
  const entradas = data?.feed?.entry || [];
  return entradas.map((entrada) => {
    const imagenes = entrada['im:image'] || [];
    return {
      // El feed RSS no trae trackId numérico directo — viene en el id del
      // link, ej. ".../id1234567890" — se extrae de ahí.
      itunesTrackId: Number(entrada.id?.attributes?.['im:id']) || 0,
      titulo: entrada['im:name']?.label || 'Sin título',
      artista: entrada['im:artist']?.label || 'Artista desconocido',
      artworkUrl: imagenes[imagenes.length - 1]?.label || '',
      previewUrl: null,
    };
  });
}

module.exports = { buscarCanciones, topCanciones };
