'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import supabase from '@/lib/supabase';

interface Artisan {
  id: string;
  nom: string;
  prenom: string;
  metier: string;
  categorie: string;
  ville: string;
  commune?: string;
  telephone: string;
  description?: string;
  avatar_url?: string;
  note?: number;
  statut: string;
  badge_verifie?: boolean;
  badge_top?: boolean;
  badge_express?: boolean;
  skills?: string[];
  realisations?: string[];
}

export default function ArtisanDetailPage() {
  const params = useParams();
  const artisanId = params.id as string;
  const [artisan, setArtisan] = useState<Artisan | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchArtisan = async () => {
      try {
        setLoading(true);
        const { data, error: err } = await supabase
          .from('providers')
          .select('*')
          .eq('id', artisanId)
          .single();

        if (err) throw err;
        setArtisan(data);
      } catch (err) {
        console.error('Erreur chargement artisan:', err);
        setError('Artisan non trouvé');
      } finally {
        setLoading(false);
      }
    };

    if (artisanId) fetchArtisan();
  }, [artisanId]);

  const getInitials = (nom: string, prenom: string) => {
    return `${prenom?.[0] || ''}${nom?.[0] || ''}`.toUpperCase();
  };

  const getAvatarColor = (id: string) => {
    const colors = [
      'from-[#f97316] to-[#c74b00]',
      'from-[#2d2d6b] to-[#0a0f2e]',
      'from-[#22c55e] to-[#16a34a]',
      'from-[#3b82f6] to-[#1d4ed8]',
      'from-[#a855f7] to-[#7c3aed]',
    ];
    return colors[id.charCodeAt(0) % colors.length];
  };

  return (
    <div className="min-h-screen bg-white">
      {/* NAVBAR */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-[#0d0d2e]/95 backdrop-blur-md border-b border-white/5">
        <div className="max-w-[1400px] mx-auto px-4 sm:px-[5%] flex items-center justify-between h-16 sm:h-[68px]">
          <Link href="/" className="flex items-center gap-2 flex-shrink-0">
            <div className="w-9 h-9 sm:w-10 sm:h-10 bg-[#f97316] rounded-[11px] flex items-center justify-center">
              <span className="text-white text-xs sm:text-sm font-bold" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>YJ</span>
            </div>
            <span className="text-white text-base sm:text-lg font-bold hidden sm:inline" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
              YOUMMA <span className="text-[#f97316]">JOBS</span>
            </span>
          </Link>
          <div className="hidden lg:flex items-center gap-6">
            <Link href="/" className="text-white/80 hover:text-white text-sm transition">Accueil</Link>
            <Link href="/artisans" className="text-white/80 hover:text-white text-sm transition">Artisans</Link>
            <Link href="/inscription" className="px-4 py-2 bg-[#f97316] text-white rounded-lg text-sm font-bold hover:bg-[#c74b00] transition">
              Devenir artisan
            </Link>
          </div>
          <Link href="/artisans" className="flex items-center gap-2 text-white hover:text-[#f97316] transition">
            <i className="fa-solid fa-arrow-left"></i>
            <span className="hidden sm:inline text-sm">Retour</span>
          </Link>
        </div>
      </nav>

      {loading ? (
        <div className="flex items-center justify-center min-h-screen">
          <div className="text-center">
            <i className="fa-solid fa-spinner fa-spin text-4xl text-[#f97316] mb-4"></i>
            <p className="text-gray-600">Chargement du profil...</p>
          </div>
        </div>
      ) : error || !artisan ? (
        <div className="flex flex-col items-center justify-center min-h-screen px-4">
          <div className="text-center">
            <i className="fa-solid fa-exclamation-circle text-4xl text-red-500 mb-4"></i>
            <p className="text-gray-600 mb-6">{error || 'Artisan non trouvé'}</p>
            <Link href="/artisans" className="px-6 py-3 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition">
              Retour aux artisans
            </Link>
          </div>
        </div>
      ) : (
        <>
          {/* HERO PROFIL */}
          <div className="pt-24 sm:pt-32 pb-12 px-4 sm:px-[5%] bg-gradient-to-b from-[#0a0f2e] to-white">
            <div className="max-w-4xl mx-auto">
              <div className="flex flex-col sm:flex-row gap-6 sm:gap-8">
                {/* Avatar */}
                <div className={`w-24 h-24 sm:w-32 sm:h-32 bg-gradient-to-br ${getAvatarColor(artisan.id)} rounded-2xl flex items-center justify-center text-white font-bold text-4xl sm:text-5xl flex-shrink-0`}>
                  {getInitials(artisan.nom, artisan.prenom)}
                </div>

                {/* Info */}
                <div className="flex-1">
                  {/* Badges */}
                  <div className="flex flex-wrap gap-2 mb-4">
                    {artisan.badge_verifie && (
                      <span className="px-3 py-1 bg-[#22c55e]/20 text-[#22c55e] rounded-full text-xs font-bold">✓ Vérifié par YOUMMA</span>
                    )}
                    {artisan.badge_top && (
                      <span className="px-3 py-1 bg-[#f59e0b]/20 text-[#f59e0b] rounded-full text-xs font-bold">⭐ Top Artisan</span>
                    )}
                    {artisan.badge_express && (
                      <span className="px-3 py-1 bg-[#f97316]/20 text-[#f97316] rounded-full text-xs font-bold">⚡ Intervention rapide</span>
                    )}
                  </div>

                  {/* Nom et métier */}
                  <h1 className="text-3xl sm:text-4xl font-bold text-white mb-2" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
                    {artisan.prenom} {artisan.nom}
                  </h1>
                  <p className="text-xl text-[#f97316] font-semibold mb-4">{artisan.metier}</p>

                  {/* Localisation */}
                  <div className="flex items-center gap-2 text-white/80 mb-6">
                    <i className="fa-solid fa-location-dot"></i>
                    <span>{artisan.commune || artisan.ville}, Guinée</span>
                  </div>

                  {/* CTAs */}
                  <div className="flex flex-col sm:flex-row gap-3">
                    <a
                      href={`https://wa.me/${artisan.telephone}?text=Bonjour, je suis intéressé par vos services`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="px-6 py-3 bg-[#22c55e] text-white rounded-lg font-bold hover:bg-[#16a34a] transition flex items-center justify-center gap-2"
                    >
                      <i className="fa-brands fa-whatsapp"></i> WhatsApp
                    </a>
                    <a
                      href={`tel:${artisan.telephone}`}
                      className="px-6 py-3 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition flex items-center justify-center gap-2"
                    >
                      <i className="fa-solid fa-phone"></i> Appeler
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* CONTENU */}
          <div className="px-4 sm:px-[5%] py-12">
            <div className="max-w-4xl mx-auto">
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Colonne principale */}
                <div className="lg:col-span-2">
                  {/* À propos */}
                  {artisan.description && (
                    <div className="mb-8">
                      <h2 className="text-2xl font-bold text-[#1a1a4e] mb-4" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
                        À propos
                      </h2>
                      <p className="text-gray-700 leading-relaxed">{artisan.description}</p>
                    </div>
                  )}

                  {/* Compétences */}
                  {artisan.skills && artisan.skills.length > 0 && (
                    <div className="mb-8">
                      <h2 className="text-2xl font-bold text-[#1a1a4e] mb-4" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
                        Compétences
                      </h2>
                      <div className="flex flex-wrap gap-3">
                        {artisan.skills.map((skill, idx) => (
                          <span key={idx} className="px-4 py-2 bg-[#f97316]/10 text-[#f97316] rounded-lg text-sm font-semibold border border-[#f97316]/30">
                            {skill}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Réalisations */}
                  {artisan.realisations && artisan.realisations.length > 0 && (
                    <div className="mb-8">
                      <h2 className="text-2xl font-bold text-[#1a1a4e] mb-4" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
                        Réalisations
                      </h2>
                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                        {artisan.realisations.map((url, idx) => (
                          <img key={idx} src={url} alt={`Réalisation ${idx + 1}`} className="w-full h-40 object-cover rounded-lg" />
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* Sidebar */}
                <div className="lg:col-span-1">
                  {/* Stats */}
                  <div className="bg-gray-50 rounded-xl p-6 mb-6">
                    <h3 className="font-bold text-[#1a1a4e] mb-4">Statistiques</h3>
                    <div className="space-y-3">
                      <div className="flex justify-between items-center">
                        <span className="text-gray-600">Catégorie</span>
                        <span className="font-semibold text-[#f97316]">{artisan.categorie}</span>
                      </div>
                      {artisan.note && (
                        <div className="flex justify-between items-center">
                          <span className="text-gray-600">Évaluation</span>
                          <div className="flex items-center gap-2">
                            <div className="flex text-[#f59e0b] text-sm">
                              {[...Array(5)].map((_, i) => (
                                <i key={i} className={`fa-solid fa-star ${i < Math.round(artisan.note || 0) ? '' : 'opacity-30'}`}></i>
                              ))}
                            </div>
                            <span className="font-semibold">{artisan.note.toFixed(1)}</span>
                          </div>
                        </div>
                      )}
                      <div className="flex justify-between items-center pt-3 border-t border-gray-200">
                        <span className="text-gray-600">Statut</span>
                        <span className={`px-3 py-1 rounded-full text-xs font-bold ${artisan.statut === 'actif' ? 'bg-[#22c55e]/20 text-[#22c55e]' : 'bg-gray-200 text-gray-600'}`}>
                          {artisan.statut === 'actif' ? '🟢 Actif' : 'En pause'}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Contact */}
                  <div className="bg-[#f97316] text-white rounded-xl p-6">
                    <h3 className="font-bold text-lg mb-4">Entrer en contact</h3>
                    <div className="space-y-3">
                      <a
                        href={`https://wa.me/${artisan.telephone}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="block w-full px-4 py-3 bg-[#22c55e] hover:bg-[#16a34a] rounded-lg font-bold text-center transition"
                      >
                        <i className="fa-brands fa-whatsapp mr-2"></i> Envoyer SMS
                      </a>
                      <a
                        href={`tel:${artisan.telephone}`}
                        className="block w-full px-4 py-3 bg-white/20 hover:bg-white/30 rounded-lg font-bold text-center transition"
                      >
                        <i className="fa-solid fa-phone mr-2"></i> Appeler maintenant
                      </a>
                    </div>
                    <p className="text-xs text-white/70 mt-4 text-center">
                      Contact direct, aucun intermédiaire
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </>
      )}

      {/* FOOTER */}
      <footer className="bg-[#1a1a4e] text-white py-12 px-4">
        <div className="max-w-6xl mx-auto text-center">
          <div className="text-sm text-white/60">
            YOUMMA JOBS © 2025 — Plateforme des artisans en Guinée
          </div>
        </div>
      </footer>
    </div>
  );
}
