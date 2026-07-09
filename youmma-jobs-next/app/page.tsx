'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import supabase from '@/lib/supabase';

interface Artisan {
  id: string;
  prenom: string;
  nom: string;
  metier: string;
  categorie: string;
  ville: string;
  note: number;
  badge_verifie: boolean;
  badge_express: boolean;
  description: string;
}

export default function Home() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [selectedCity, setSelectedCity] = useState('');
  const [searchResults, setSearchResults] = useState<Artisan[]>([]);
  const [loading, setLoading] = useState(false);

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

  useEffect(() => {
    const searchArtisans = async () => {
      setLoading(true);
      try {
        let query = supabase
          .from('providers')
          .select('*')
          .eq('statut', 'actif')
          .limit(6);

        if (selectedCategory) query = query.eq('categorie', selectedCategory);
        if (selectedCity) query = query.eq('ville', selectedCity);
        if (searchQuery) {
          query = query.or(
            `nom.ilike.%${searchQuery}%,prenom.ilike.%${searchQuery}%,metier.ilike.%${searchQuery}%,description.ilike.%${searchQuery}%`
          );
        }

        const { data, error } = await query;
        if (error) throw error;
        setSearchResults(data || []);
      } catch (err) {
        console.error('Erreur recherche:', err);
        setSearchResults([]);
      } finally {
        setLoading(false);
      }
    };

    const timer = setTimeout(searchArtisans, 300);
    return () => clearTimeout(timer);
  }, [searchQuery, selectedCategory, selectedCity]);

  return (
    <div className="min-h-screen">

      {/* ============ NAVBAR ============ */}
      <nav className="fixed top-0 left-0 right-0 z-50 bg-[#0d0d2e]/95 backdrop-blur-md border-b border-white/5">
        <div className="max-w-[1400px] mx-auto px-4 sm:px-[5%] flex items-center justify-between h-16 sm:h-[68px]">
          <Link href="/" className="flex items-center gap-2 flex-shrink-0">
            <div className="w-9 h-9 sm:w-10 sm:h-10 bg-[#f97316] rounded-[11px] flex items-center justify-center">
              <span className="text-white text-xs sm:text-sm font-bold">YJ</span>
            </div>
            <span className="text-white text-base sm:text-lg font-bold hidden sm:inline">
              YOUMMA <span className="text-[#f97316]">JOBS</span>
            </span>
          </Link>

          <div className="hidden lg:flex items-center gap-1 flex-1 mx-6">
            <Link href="/" className="px-3 py-2 text-white/80 hover:text-white text-sm transition">Accueil</Link>
            <Link href="/artisans" className="px-3 py-2 text-white/80 hover:text-white text-sm transition">Artisans</Link>
            <a href="#categories" className="px-3 py-2 text-white/80 hover:text-white text-sm transition">Catégories</a>
          </div>

          <div className="hidden sm:flex items-center gap-2">
            <Link href="/connexion" className="px-3 py-2 sm:px-4 text-white/80 hover:text-white text-xs sm:text-sm font-semibold transition">
              Connexion
            </Link>
            <Link href="/inscription" className="px-4 py-2 bg-[#f97316] text-white rounded-lg text-xs sm:text-sm font-bold hover:bg-[#c74b00] transition">
              +Devenir artisan
            </Link>
          </div>

          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="lg:hidden text-white p-2 hover:bg-white/10 rounded-lg transition"
          >
            <span className="text-lg">{mobileMenuOpen ? '✕' : '☰'}</span>
          </button>
        </div>

        {mobileMenuOpen && (
          <div className="lg:hidden bg-[#0a0f2e] border-t border-white/10 px-4 py-4 space-y-2">
            <Link href="/" onClick={() => setMobileMenuOpen(false)} className="block px-4 py-2 text-white hover:text-[#f97316] text-sm transition">Accueil</Link>
            <Link href="/artisans" onClick={() => setMobileMenuOpen(false)} className="block px-4 py-2 text-white hover:text-[#f97316] text-sm transition">Artisans</Link>
            <div className="border-t border-white/10 pt-3 mt-2 space-y-2">
              <Link href="/connexion" onClick={() => setMobileMenuOpen(false)} className="block px-4 py-2 text-white hover:text-[#f97316] text-sm transition">Connexion</Link>
              <Link href="/inscription" onClick={() => setMobileMenuOpen(false)} className="block w-full px-4 py-2 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition text-sm text-center">
                +Devenir artisan
              </Link>
            </div>
          </div>
        )}
      </nav>

      {/* ============ HERO ============ */}
      {/* padding-top: 68px = hauteur navbar fixe */}
      <section
        id="home"
        style={{
          background: 'linear-gradient(135deg, #0a0f2e 0%, #1a1a4e 100%)',
          paddingTop: '68px', /* compense la navbar fixed */
        }}
        className="pb-12 sm:pb-20 px-4 sm:px-[5%] relative overflow-hidden"
      >
        {/* Background blobs */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute top-10 right-10 w-72 h-72 bg-[#f97316]/10 rounded-full blur-3xl"></div>
          <div className="absolute bottom-20 left-10 w-96 h-96 bg-[#2d2d6b]/30 rounded-full blur-3xl"></div>
        </div>

        <div className="max-w-6xl mx-auto relative z-10 pt-10 sm:pt-16">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 sm:gap-16 items-center">

            {/* LEFT */}
            <div>
              <div className="flex items-center gap-3 mb-6">
                <span className="text-2xl">🇬🇳</span>
                <div className="h-px w-6 bg-white/30"></div>
                <span className="text-xs sm:text-sm text-white/70 font-semibold">Plateforme N°1 des artisans en Guinée</span>
              </div>

              <h1 className="text-3xl sm:text-5xl font-bold text-white mb-4 sm:mb-6 leading-tight">
                Trouvez votre<br/>
                <em className="text-[#f97316] italic">artisan</em> en Guinée
              </h1>

              <p className="text-sm sm:text-base text-white/70 mb-6 sm:mb-8 max-w-lg">
                Trouvez rapidement le bon artisan pour tous vos projets — électriciens, plombiers, maçons, soudeurs, menuisiers, mécaniciens et bien plus.
              </p>

              <div className="flex flex-col sm:flex-row gap-3 sm:gap-4 mb-8 sm:mb-12">
                <Link href="/artisans" className="px-6 py-3 sm:py-4 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition flex items-center justify-center gap-2 text-sm sm:text-base">
                  🔍 Trouver un artisan
                </Link>
                <Link href="/inscription" className="px-6 py-3 sm:py-4 bg-transparent border-2 border-white text-white rounded-lg font-bold hover:bg-white/10 transition flex items-center justify-center gap-2 text-sm sm:text-base">
                  🚀 Devenir artisan
                </Link>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-6 sm:pt-8 border-t border-white/10">
                {[
                  { val: '500+', label: 'Prestataires vérifiés', color: 'text-white' },
                  { val: '20+', label: 'Catégories', color: 'text-white' },
                  { val: '10k+', label: 'Clients', color: 'text-white' },
                  { val: '100%', label: 'Profils vérifiés', color: 'text-[#f97316]' },
                ].map(s => (
                  <div key={s.label}>
                    <div className={`text-2xl sm:text-3xl font-bold mb-1 ${s.color}`}>{s.val}</div>
                    <div className="text-xs text-white/60">{s.label}</div>
                  </div>
                ))}
              </div>
            </div>

            {/* RIGHT — carte décorative, desktop seulement */}
            <div className="hidden lg:block">
              <div
                className="bg-gradient-to-br from-white/10 to-white/5 rounded-2xl border border-white/20 backdrop-blur-md p-6"
                style={{ boxShadow: '0 20px 60px rgba(0,0,0,.3)' }}
              >
                <span className="px-3 py-1 bg-[#22c55e]/20 text-[#22c55e] rounded-full text-xs font-bold inline-block mb-4">✅ Vérifié</span>

                <div className="flex items-center gap-3 mb-4">
                  <div className="w-12 h-12 bg-gradient-to-br from-[#f97316] to-[#c74b00] rounded-full flex items-center justify-center text-white font-bold">
                    AD
                  </div>
                  <div>
                    <div className="font-bold text-white">Amadou Diallo</div>
                    <div className="text-sm text-white/60">Électricien · Ratoma</div>
                  </div>
                </div>

                <div className="flex flex-wrap gap-2 mb-4">
                  {['Installation', 'Dépannage', 'Câblage'].map(s => (
                    <span key={s} className="px-2 py-1 bg-white/10 text-white rounded text-xs">{s}</span>
                  ))}
                </div>

                <div className="grid grid-cols-3 gap-2 pt-4 border-t border-white/10 mb-4">
                  {[{ val: '142', label: 'Vues' }, { val: '47', label: 'Missions' }, { val: '5.0', label: 'Note', orange: true }].map(s => (
                    <div key={s.label} className="text-center">
                      <div className={`text-lg font-bold ${s.orange ? 'text-[#f97316]' : 'text-white'}`}>{s.val}</div>
                      <div className="text-xs text-white/60">{s.label}</div>
                    </div>
                  ))}
                </div>

                <div className="flex gap-2">
                  <button className="flex-1 px-3 py-2 bg-[#22c55e]/20 text-[#22c55e] rounded-lg text-xs font-bold hover:bg-[#22c55e]/30 transition">
                    💬 WhatsApp
                  </button>
                  <button className="flex-1 px-3 py-2 bg-white/10 text-white rounded-lg text-xs font-bold hover:bg-white/20 transition">
                    📞 Appeler
                  </button>
                </div>
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* ============ SEARCH ============ */}
      <section className="bg-white py-8 sm:py-12 px-4 sm:px-[5%] border-b border-gray-200">
        <div className="max-w-6xl mx-auto">
          <div className="bg-white rounded-2xl p-4 sm:p-6 shadow-lg border border-gray-100">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 mb-4">
              <div className="relative sm:col-span-2 lg:col-span-1">
                <input
                  type="text"
                  placeholder="🔍 Métier, artisan..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full px-4 py-3 border border-gray-200 rounded-lg text-sm focus:outline-none focus:border-[#f97316] transition"
                />
              </div>

              <select
                value={selectedCity}
                onChange={(e) => setSelectedCity(e.target.value)}
                className="w-full px-4 py-3 border border-gray-200 rounded-lg text-sm focus:outline-none focus:border-[#f97316] bg-white transition"
              >
                {cities.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>

              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="w-full px-4 py-3 border border-gray-200 rounded-lg text-sm focus:outline-none focus:border-[#f97316] bg-white transition"
              >
                {categories.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>

              <Link href="/artisans" className="px-4 py-3 bg-[#f97316] text-white font-bold rounded-lg hover:bg-[#c74b00] transition flex items-center justify-center gap-2 text-sm">
                🔍 Voir plus
              </Link>
            </div>

            {(searchQuery || selectedCategory || selectedCity) && (
              <div className="text-xs sm:text-sm text-gray-600 mb-3">
                {loading ? 'Recherche...' : `${searchResults.length} résultat${searchResults.length !== 1 ? 's' : ''} trouvé${searchResults.length !== 1 ? 's' : ''}`}
              </div>
            )}

            <button
              onClick={() => { setSearchQuery(''); setSelectedCategory(''); setSelectedCity(''); }}
              className="px-3 py-1.5 bg-gray-100 text-gray-700 text-xs font-bold rounded-full hover:bg-gray-200 transition"
            >
              ✕ Réinitialiser
            </button>
          </div>
        </div>
      </section>

      {/* ============ RÉSULTATS LIVE ============ */}
      {(searchQuery || selectedCategory || selectedCity) && searchResults.length > 0 && (
        <section className="bg-gray-50 py-12 px-4 sm:px-[5%]">
          <div className="max-w-6xl mx-auto">
            <h2 className="text-2xl sm:text-3xl font-bold text-gray-900 mb-8">Résultats de recherche</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {searchResults.map((artisan) => (
                <Link key={artisan.id} href={`/artisans/${artisan.id}`}>
                  <div className="bg-white rounded-2xl p-6 border border-gray-200 hover:shadow-lg transition h-full">
                    <div className="flex items-start justify-between mb-4">
                      <div className="w-12 h-12 bg-gradient-to-br from-[#f97316] to-[#c74b00] rounded-full flex items-center justify-center text-white font-bold text-sm">
                        {artisan.prenom.charAt(0)}{artisan.nom.charAt(0)}
                      </div>
                      <div className="flex gap-2">
                        {artisan.badge_verifie && <span className="px-2 py-1 bg-[#22c55e]/20 text-[#22c55e] rounded-full text-xs font-bold">✓</span>}
                        {artisan.badge_express && <span className="px-2 py-1 bg-[#f97316]/20 text-[#f97316] rounded-full text-xs font-bold">⚡</span>}
                      </div>
                    </div>
                    <h3 className="font-bold text-gray-900">{artisan.prenom} {artisan.nom}</h3>
                    <p className="text-sm text-gray-600 mb-1">{artisan.metier}</p>
                    <p className="text-xs text-gray-500 mb-3">📍 {artisan.ville}</p>
                    <p className="text-sm text-gray-600 line-clamp-2 mb-4">{artisan.description}</p>
                    <button className="w-full px-4 py-2 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition text-sm">
                      Voir le profil
                    </button>
                  </div>
                </Link>
              ))}
            </div>
          </div>
        </section>
      )}

      {/* ============ CATÉGORIES ============ */}
      <section id="categories" className="py-16 sm:py-20 px-4 sm:px-[5%]">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-12">
            <h2 className="text-2xl sm:text-4xl font-bold text-gray-900 mb-3">
              Explorez nos <span className="text-[#f97316]">artisans</span>
            </h2>
            <p className="text-sm sm:text-base text-gray-600">Découvrez des centaines de professionnels vérifiés en Guinée.</p>
          </div>

          <div className="mb-10">
            <Link href="/artisans" className="px-6 py-3 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition inline-flex items-center gap-2 text-sm">
              → Voir tous les artisans
            </Link>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              { icon: '🔨', title: 'Électriciens', desc: 'Installation, dépannage, maintenance' },
              { icon: '🔧', title: 'Plombiers', desc: 'Réparation, installation, urgences' },
              { icon: '🏗️', title: 'Maçons', desc: 'Construction, rénovation, carrelage' },
              { icon: '✂️', title: 'Coiffeurs', desc: 'Coupe, coiffure, soins capillaires' },
              { icon: '🧵', title: 'Couturiers', desc: 'Confection, retouche, création' },
              { icon: '🚗', title: 'Mécaniciens', desc: 'Entretien, réparation, diagnostic' },
            ].map((item, i) => (
              <Link key={i} href={`/artisans?categorie=${item.title}`}>
                <div className="bg-gradient-to-br from-gray-50 to-white rounded-2xl p-6 border border-gray-200 hover:shadow-lg hover:border-[#f97316]/30 transition cursor-pointer">
                  <div className="text-4xl mb-4">{item.icon}</div>
                  <h3 className="text-lg font-bold text-[#1a1a4e] mb-2">{item.title}</h3>
                  <p className="text-sm text-gray-600">{item.desc}</p>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* ============ FOOTER ============ */}
      <footer className="bg-[#1a1a4e] text-white py-8 sm:py-12 px-4 sm:px-[5%]">
        <div className="max-w-6xl mx-auto text-center">
          <div className="text-lg font-bold mb-4">YOUMMA <span className="text-[#f97316]">JOBS</span></div>
          <div className="flex justify-center gap-6 mb-6 flex-wrap">
            <Link href="/artisans" className="text-white/60 hover:text-white text-sm transition">Artisans</Link>
            <Link href="/inscription" className="text-white/60 hover:text-white text-sm transition">S'inscrire</Link>
            <Link href="/connexion" className="text-white/60 hover:text-white text-sm transition">Connexion</Link>
          </div>
          <div className="text-xs text-white/60">YOUMMA JOBS © 2025 — Plateforme des artisans en Guinée</div>
        </div>
      </footer>

    </div>
  );
}