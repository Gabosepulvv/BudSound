const ITUNES_SEARCH_URL = 'https://itunes.apple.com/search';

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

module.exports = { buscarCanciones };
