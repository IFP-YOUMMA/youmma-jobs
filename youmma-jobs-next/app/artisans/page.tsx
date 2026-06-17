'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
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
}

export default function ArtisansPage() {
  const [artisans, setArtisans] = useState<Artisan[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [selectedCity, setSelectedCity] = useState('');
  const [filteredArtisans, setFilteredArtisans] = useState<Artisan[]>([]);

  const categories = [
    { value: '', label: 'Toutes catégories' },
    { value: 'Artisans', label: '🔨 Artisans' },
    { value: 'Santé & Beauté', label: '🏥 Santé & Beauté' },
    { value: 'Construction & BTP', label: '🏗️ Construction & BTP' },
    { value: 'IT', label: '💻 IT & Digital' },
    { value: 'Éducation', label: '📚 Éducation' },
    { value: 'Transport', label: '🚗 Transport' },
    { value: 'Juridique', label: '⚖️ Services Pro' },
  ];

  const cities = [
    { value: '', label: 'Toutes les villes' },
    { value: 'Kaloum', label: 'Kaloum' },
    { value: 'Dixinn', label: 'Dixinn' },
    { value: 'Matam', label: 'Matam' },
    { value: 'Ratoma', label: 'Ratoma' },
    { value: 'Matoto', label: 'Matoto' },
    { value: 'Kindia', label: 'Kindia' },
    { value: 'Kankan', label: 'Kankan' },
    { value: 'Labé', label: 'Labé' },
  ];

  // Charger les artisans
  useEffect(() => {
    const fetchArtisans = async () => {
      try {
        setLoading(true);
        const { data, error } = await supabase
          .from('providers')
          .select('*')
          .eq('statut', 'actif')
          .limit(50);

        if (error) throw error;
        setArtisans(data || []);
      } catch (err) {
        console.error('Erreur chargement artisans:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchArtisans();
  }, []);

  // Filtrer les artisans
  useEffect(() => {
    let filtered = artisans;

    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      filtered = filtered.filter(a =>
        (a.nom?.toLowerCase().includes(q) ||
          a.prenom?.toLowerCase().includes(q) ||
          a.metier?.toLowerCase().includes(q) ||
          a.description?.toLowerCase().includes(q))
      );
    }

    if (selectedCategory) {
      filtered = filtered.filter(a => a.categorie === selectedCategory);
    }

    if (selectedCity) {
      filtered = filtered.filter(a =>
        a.ville === selectedCity || a.commune === selectedCity
      );
    }

    setFilteredArtisans(filtered);
  }, [searchQuery, selectedCategory, selectedCity, artisans]);

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
            <Link href="/artisans" className="text-[#f97316] text-sm font-semibold">Artisans</Link>
            <Link href="/inscription" className="px-4 py-2 bg-[#f97316] text-white rounded-lg text-sm font-bold hover:bg-[#c74b00] transition">
              Devenir artisan
            </Link>
          </div>
          <Link href="/" className="lg:hidden text-white">
            <i className="fa-solid fa-arrow-left"></i>
          </Link>
        </div>
      </nav>

      {/* HEADER */}
      <div className="pt-24 sm:pt-32 pb-12 px-4 sm:px-[5%] bg-gradient-to-b from-[#0a0f2e] to-white">
        <div className="max-w-6xl mx-auto">
          <h1 className="text-3xl sm:text-5xl font-bold text-[#1a1a4e] mb-2" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
            Artisans <span className="text-[#f97316]">vérifiés</span> en Guinée
          </h1>
          <p className="text-gray-600 text-base sm:text-lg">{filteredArtisans.length} professionnel(s) trouvé(s)</p>
        </div>
      </div>

      {/* FILTRES */}
      <div className="px-4 sm:px-[5%] py-8 border-b border-gray-200">
        <div className="max-w-6xl mx-auto">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
            {/* Recherche */}
            <div className="relative">
              <i className="fa-solid fa-magnifying-glass absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400"></i>
              <input
                type="text"
                placeholder="Métier, nom..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-lg text-sm focus:outline-none focus:border-[#f97316]"
              />
            </div>

            {/* Catégorie */}
            <div className="relative">
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="w-full px-4 py-3 border border-gray-200 rounded-lg text-sm focus:outline-none focus:border-[#f97316] appearance-none bg-white"
              >
                {categories.map(cat => (
                  <option key={cat.value} value={cat.value}>{cat.label}</option>
                ))}
              </select>
            </div>

            {/* Ville */}
            <div className="relative">
              <i className="fa-solid fa-location-dot absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400"></i>
              <select
                value={selectedCity}
                onChange={(e) => setSelectedCity(e.target.value)}
                className="w-full pl-10 pr-4 py-3 border border-gray-200 rounded-lg text-sm focus:outline-none focus:border-[#f97316] appearance-none bg-white"
              >
                {cities.map(city => (
                  <option key={city.value} value={city.value}>{city.label}</option>
                ))}
              </select>
            </div>

            {/* Reset */}
            {(searchQuery || selectedCategory || selectedCity) && (
              <button
                onClick={() => {
                  setSearchQuery('');
                  setSelectedCategory('');
                  setSelectedCity('');
                }}
                className="px-4 py-3 bg-white border border-[#f97316] text-[#f97316] rounded-lg text-sm font-bold hover:bg-[#f97316]/5 transition"
              >
                ✕ Réinitialiser
              </button>
            )}
          </div>
        </div>
      </div>

      {/* GRILLE ARTISANS */}
      <div className="px-4 sm:px-[5%] py-12">
        <div className="max-w-6xl mx-auto">
          {loading ? (
            <div className="text-center py-20">
              <i className="fa-solid fa-spinner fa-spin text-3xl text-[#f97316] mb-4"></i>
              <p className="text-gray-600">Chargement des artisans...</p>
            </div>
          ) : filteredArtisans.length === 0 ? (
            <div className="text-center py-20">
              <p className="text-gray-600 text-lg mb-4">Aucun artisan trouvé</p>
              <button
                onClick={() => {
                  setSearchQuery('');
                  setSelectedCategory('');
                  setSelectedCity('');
                }}
                className="px-6 py-3 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition"
              >
                Voir tous les artisans
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {filteredArtisans.map((artisan) => (
                <Link key={artisan.id} href={`/artisans/${artisan.id}`}>
                  <div className="bg-white border border-gray-200 rounded-2xl p-6 hover:shadow-lg hover:border-[#f97316] transition cursor-pointer h-full">
                    {/* Avatar */}
                    <div className={`w-16 h-16 bg-gradient-to-br ${getAvatarColor(artisan.id)} rounded-xl flex items-center justify-center text-white font-bold text-lg mb-4`}>
                      {getInitials(artisan.nom, artisan.prenom)}
                    </div>

                    {/* Badges */}
                    <div className="flex flex-wrap gap-2 mb-3">
                      {artisan.badge_verifie && (
                        <span className="px-2 py-1 bg-[#22c55e]/20 text-[#22c55e] rounded text-xs font-bold">✓ Vérifié</span>
                      )}
                      {artisan.badge_top && (
                        <span className="px-2 py-1 bg-[#f59e0b]/20 text-[#f59e0b] rounded text-xs font-bold">⭐ Top</span>
                      )}
                      {artisan.badge_express && (
                        <span className="px-2 py-1 bg-[#f97316]/20 text-[#f97316] rounded text-xs font-bold">⚡ Express</span>
                      )}
                    </div>

                    {/* Nom et métier */}
                    <h3 className="text-lg font-bold text-[#1a1a4e] mb-1">
                      {artisan.prenom} {artisan.nom}
                    </h3>
                    <p className="text-sm font-semibold text-[#f97316] mb-2">{artisan.metier}</p>

                    {/* Localisation */}
                    <p className="text-xs text-gray-600 mb-3 flex items-center gap-1">
                      <i className="fa-solid fa-location-dot"></i>
                      {artisan.commune || artisan.ville}
                    </p>

                    {/* Description */}
                    {artisan.description && (
                      <p className="text-sm text-gray-600 mb-4 line-clamp-2">
                        {artisan.description}
                      </p>
                    )}

                    {/* Rating */}
                    {artisan.note && (
                      <div className="flex items-center gap-2 mb-4 pb-4 border-t border-gray-100 pt-4">
                        <div className="flex text-[#f59e0b]">
                          {[...Array(5)].map((_, i) => (
                            <i key={i} className={`fa-solid fa-star text-xs ${i < Math.round(artisan.note || 0) ? '' : 'opacity-30'}`}></i>
                          ))}
                        </div>
                        <span className="text-sm font-semibold text-[#1a1a4e]">{artisan.note.toFixed(1)}</span>
                      </div>
                    )}

                    {/* CTA */}
                    <button className="w-full px-4 py-2 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition text-sm">
                      Voir le profil
                    </button>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </div>
      </div>

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
