const ITUNES_SEARCH_URL = 'https://itunes.apple.com/search';
const ITUNES_TOP_SONGS_URL = 'https://itunes.apple.com/us/rss/topsongs';

// Mapeo "mejor esfuerzo" de los géneros fijos de BudSound (ver
// GENEROS_VALIDOS en event.controller.js) a la taxonomía de géneros de
// iTunes/Apple Music — no son el mismo catálogo, así que esto es una
// aproximación, no una equivalencia exacta (ej. "Reggaetón", "Cumbia",
// "Salsa" y "Bachata" caen todos dentro del género amplio "Latin" de
// iTunes, que no distingue entre ellos).
//
// `genreId` sirve para el feed RSS "top songs" (`/rss/topsongs/.../genre=X`
// — SÍ filtra de verdad, se probó a mano contra la API real). `nombres` es
// la lista de substrings de `primaryGenreName` que la Search API SÍ
// devuelve por canción, usada para filtrar resultados DESPUÉS de
// recibirlos — la Search API ignora por completo su propio parámetro
// `genreId` en cuanto se le manda un `term` (se comprobó a mano: los
// resultados son idénticos con y sin `genreId`), así que no hay forma de
// filtrar la búsqueda libre en el pedido mismo, solo en lo que ya devolvió.
//
// `Variado` (y cualquier género no listado acá) no filtra nada.
const GENERO_A_ITUNES = {
  Reggaetón: { genreId: 12, nombres: ['latin'] },
  Pop: { genreId: 14, nombres: ['pop'] },
  Rock: { genreId: 21, nombres: ['rock'] },
  Electrónica: { genreId: 7, nombres: ['electronic', 'dance'] },
  Cumbia: { genreId: 12, nombres: ['latin', 'mexican'] },
  'Hip-Hop/Rap': { genreId: 18, nombres: ['hip-hop', 'rap'] },
  Salsa: { genreId: 12, nombres: ['latin'] },
  Bachata: { genreId: 12, nombres: ['latin'] },
  'Techno/House': { genreId: 7, nombres: ['electronic', 'dance', 'house', 'techno'] },
  Indie: { genreId: 20, nombres: ['alternative', 'indie'] },
  Trap: { genreId: 18, nombres: ['hip-hop', 'rap', 'trap'] },
};

function infoGeneros(generos) {
  return (generos || [])
    .map((g) => GENERO_A_ITUNES[g])
    .filter(Boolean);
}

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
    // Se usa solo para el filtrado por género de `buscarCancionesPorGeneros`
    // — no hace falta que el frontend la use, pero no cuesta nada dejarla.
    generoItunes: track.primaryGenreName || null,
  }));
}

// Mismo resultado que `buscarCanciones`, pero recortado a los géneros del
// evento (ver GENERO_A_ITUNES arriba) — filtrado DESPUÉS de recibir los
// resultados, porque la Search API no lo hace de verdad. Pide de más
// (`limit * 4`) para que el filtrado no deje la lista casi vacía cuando el
// término es específico.
async function buscarCancionesPorGeneros(term, generos, { limit = 15 } = {}) {
  const infos = infoGeneros(generos);
  if (infos.length === 0) return buscarCanciones(term, { limit });

  const nombresValidos = new Set(infos.flatMap((i) => i.nombres));
  const resultados = await buscarCanciones(term, { limit: limit * 4 });
  const filtrados = resultados.filter((r) => {
    const genero = (r.generoItunes || '').toLowerCase();
    return [...nombresValidos].some((n) => genero.includes(n));
  });
  return filtrados.slice(0, limit);
}

// Feed RSS de "Top Songs" (gratis, sin key, es una API distinta de Search)
// — para que la búsqueda no arranque vacía: el participante ve canciones
// reales y populares de entrada, en vez de una pantalla en blanco hasta
// que escriba algo.
async function topCanciones({ limit = 20, genreId } = {}) {
  const sufijoGenero = genreId ? `/genre=${genreId}` : '';
  const response = await fetch(`${ITUNES_TOP_SONGS_URL}/limit=${limit}${sufijoGenero}/json`);
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

// "Populares" acotado a los géneros del evento — a diferencia de la
// búsqueda libre, el feed RSS SÍ filtra de verdad por género (se probó a
// mano), así que esto no es una aproximación post-hoc como
// `buscarCancionesPorGeneros`. Si el evento declaró varios géneros que
// mapean a distintos `genreId` de iTunes, se pide un feed por cada uno y
// se mezclan (repartiendo el límite entre ellos) para no mostrar solo el
// primero.
async function topCancionesPorGeneros(generos, { limit = 20 } = {}) {
  const infos = infoGeneros(generos);
  if (infos.length === 0) return topCanciones({ limit });

  const idsUnicos = [...new Set(infos.map((i) => i.genreId))];
  const limitePorGenero = Math.max(4, Math.ceil(limit / idsUnicos.length));

  const listas = await Promise.all(
    idsUnicos.map((genreId) =>
      topCanciones({ limit: limitePorGenero, genreId }).catch(() => []),
    ),
  );

  const vistos = new Set();
  const mezcladas = [];
  // Intercalado (una de cada lista por vuelta) en vez de concatenado, para
  // que con 2+ géneros no queden todas las canciones del primero antes que
  // ninguna del segundo.
  for (let i = 0; i < limitePorGenero; i += 1) {
    for (const lista of listas) {
      const cancion = lista[i];
      if (!cancion || vistos.has(cancion.itunesTrackId)) continue;
      vistos.add(cancion.itunesTrackId);
      mezcladas.push(cancion);
    }
  }
  return mezcladas.slice(0, limit);
}

module.exports = {
  buscarCanciones,
  buscarCancionesPorGeneros,
  topCanciones,
  topCancionesPorGeneros,
};
