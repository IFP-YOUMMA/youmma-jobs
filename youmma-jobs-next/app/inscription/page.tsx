'use client';

import { useState } from 'react';
import Link from 'next/link';
import supabase from '@/lib/supabase';

export default function InscriptionPage() {
  const [formData, setFormData] = useState({
    prenom: '',
    nom: '',
    telephone: '',
    email: '',
    metier: '',
    categorie: '',
    ville: '',
    commune: '',
    description: '',
    password: '',
    confirmPassword: '',
  });

  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const categories = [
    { value: '', label: '— Sélectionner une catégorie —' },
    { value: 'Artisans', label: 'Artisans' },
    { value: 'Santé & Beauté', label: 'Santé & Beauté' },
    { value: 'Construction & BTP', label: 'Construction & BTP' },
    { value: 'IT', label: 'IT & Digital' },
    { value: 'Éducation', label: 'Éducation' },
    { value: 'Transport', label: 'Transport' },
    { value: 'Juridique', label: 'Services Pro' },
  ];

  const cities = [
    { value: '', label: '— Sélectionner une ville —' },
    { value: 'Kaloum', label: 'Kaloum' },
    { value: 'Dixinn', label: 'Dixinn' },
    { value: 'Matam', label: 'Matam' },
    { value: 'Ratoma', label: 'Ratoma' },
    { value: 'Matoto', label: 'Matoto' },
    { value: 'Kindia', label: 'Kindia' },
    { value: 'Kankan', label: 'Kankan' },
    { value: 'Labé', label: 'Labé' },
  ];

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      // Validation
      if (!formData.prenom || !formData.nom || !formData.telephone) {
        throw new Error('Veuillez remplir tous les champs obligatoires');
      }

      if (formData.password !== formData.confirmPassword) {
        throw new Error('Les mots de passe ne correspondent pas');
      }

      if (formData.password.length < 6) {
        throw new Error('Le mot de passe doit contenir au moins 6 caractères');
      }

      // Hash du mot de passe (simple - à améliorer en production)
      const hashPassword = async (pwd: string) => {
        const encoder = new TextEncoder();
        const data = encoder.encode(pwd);
        const hash = await crypto.subtle.digest('SHA-256', data);
        return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, '0')).join('');
      };

      const passwordHash = await hashPassword(formData.password);

      // Insérer dans Supabase
      const { data, error: insertError } = await supabase
        .from('providers')
        .insert({
          nom: formData.nom,
          prenom: formData.prenom,
          telephone: formData.telephone,
          email: formData.email || null,
          metier: formData.metier,
          categorie: formData.categorie,
          ville: formData.ville,
          commune: formData.commune || null,
          description: formData.description,
          password_hash: passwordHash,
          statut: 'en_attente',
          badge_verifie: false,
        })
        .select()
        .single();

      if (insertError) throw insertError;

      setSuccess(true);
      setFormData({
        prenom: '',
        nom: '',
        telephone: '',
        email: '',
        metier: '',
        categorie: '',
        ville: '',
        commune: '',
        description: '',
        password: '',
        confirmPassword: '',
      });

      // Rediriger après 2 secondes
      setTimeout(() => {
        window.location.href = '/';
      }, 2000);
    } catch (err: any) {
      console.error('Erreur inscription:', err);
      setError(err.message || 'Erreur lors de l\'inscription');
    } finally {
      setLoading(false);
    }
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
          <Link href="/" className="flex items-center gap-2 text-white hover:text-[#f97316] transition">
            <i className="fa-solid fa-arrow-left"></i>
            <span className="hidden sm:inline text-sm">Retour</span>
          </Link>
        </div>
      </nav>

      {/* HEADER */}
      <div className="pt-24 sm:pt-32 pb-12 px-4 sm:px-[5%] bg-gradient-to-b from-[#0a0f2e] to-white">
        <div className="max-w-2xl mx-auto text-center">
          <h1 className="text-3xl sm:text-5xl font-bold text-white mb-4" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
            Devenez <span className="text-[#f97316]">artisan</span> sur YOUMMA JOBS
          </h1>
          <p className="text-white/70 text-base sm:text-lg">
            Rejoignez des centaines de professionnels qui trouvent des clients chaque jour
          </p>
        </div>
      </div>

      {/* FORMULAIRE */}
      <div className="px-4 sm:px-[5%] py-12">
        <div className="max-w-2xl mx-auto">
          {success ? (
            <div className="bg-[#22c55e]/10 border-2 border-[#22c55e] rounded-xl p-8 text-center">
              <i className="fa-solid fa-circle-check text-4xl text-[#22c55e] mb-4"></i>
              <h2 className="text-2xl font-bold text-[#1a1a4e] mb-2">Inscription réussie !</h2>
              <p className="text-gray-700 mb-6">
                Votre profil est maintenant en attente de vérification. Vous recevrez un email de confirmation sous peu.
              </p>
              <Link href="/" className="px-6 py-3 bg-[#f97316] text-white rounded-lg font-bold hover:bg-[#c74b00] transition inline-block">
                Retour à l'accueil
              </Link>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="bg-white border border-gray-200 rounded-2xl p-8">
              {error && (
                <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700">
                  <i className="fa-solid fa-exclamation-circle mr-2"></i>
                  {error}
                </div>
              )}

              {/* Infos personnelles */}
              <h2 className="text-2xl font-bold text-[#1a1a4e] mb-6" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
                1. Informations personnelles
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
                <input
                  type="text"
                  name="prenom"
                  placeholder="Prénom *"
                  value={formData.prenom}
                  onChange={handleChange}
                  required
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20"
                />
                <input
                  type="text"
                  name="nom"
                  placeholder="Nom *"
                  value={formData.nom}
                  onChange={handleChange}
                  required
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
                <input
                  type="tel"
                  name="telephone"
                  placeholder="Téléphone (224...) *"
                  value={formData.telephone}
                  onChange={handleChange}
                  required
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20"
                />
                <input
                  type="email"
                  name="email"
                  placeholder="Email (optionnel)"
                  value={formData.email}
                  onChange={handleChange}
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20"
                />
              </div>

              {/* Professionnel */}
              <h2 className="text-2xl font-bold text-[#1a1a4e] mb-6 mt-8" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
                2. Informations professionnelles
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
                <input
                  type="text"
                  name="metier"
                  placeholder="Votre métier / spécialité *"
                  value={formData.metier}
                  onChange={handleChange}
                  required
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20"
                />
                <select
                  name="categorie"
                  value={formData.categorie}
                  onChange={handleChange}
                  required
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20 appearance-none bg-white"
                >
                  {categories.map(cat => (
                    <option key={cat.value} value={cat.value}>{cat.label}</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
                <select
                  name="ville"
                  value={formData.ville}
                  onChange={handleChange}
                  required
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20 appearance-none bg-white"
                >
                  {cities.map(city => (
                    <option key={city.value} value={city.value}>{city.label}</option>
                  ))}
                </select>
                <input
                  type="text"
                  name="commune"
                  placeholder="Commune (optionnel)"
                  value={formData.commune}
                  onChange={handleChange}
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20"
                />
              </div>

              <textarea
                name="description"
                placeholder="Décrivez votre expérience et services (optionnel)"
                value={formData.description}
                onChange={handleChange}
                rows={4}
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20 mb-8"
              />

              {/* Sécurité */}
              <h2 className="text-2xl font-bold text-[#1a1a4e] mb-6 mt-8" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
                3. Sécurité du compte
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-8">
                <input
                  type="password"
                  name="password"
                  placeholder="Mot de passe *"
                  value={formData.password}
                  onChange={handleChange}
                  required
                  minLength={6}
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20"
                />
                <input
                  type="password"
                  name="confirmPassword"
                  placeholder="Confirmer le mot de passe *"
                  value={formData.confirmPassword}
                  onChange={handleChange}
                  required
                  minLength={6}
                  className="px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20"
                />
              </div>

              {/* CTA */}
              <button
                type="submit"
                disabled={loading}
                className={`w-full px-6 py-4 ${loading ? 'bg-gray-400 cursor-not-allowed' : 'bg-[#f97316] hover:bg-[#c74b00]'} text-white rounded-lg font-bold transition text-lg mb-4`}
              >
                {loading ? (
                  <>
                    <i className="fa-solid fa-spinner fa-spin mr-2"></i>
                    Inscription en cours...
                  </>
                ) : (
                  <>
                    <i className="fa-solid fa-check mr-2"></i>
                    Créer mon profil gratuit
                  </>
                )}
              </button>

              <p className="text-center text-gray-600 text-sm">
                En cliquant, vous acceptez nos conditions d'utilisation et la vérification de votre profil.
              </p>
            </form>
          )}
        </div>
      </div>

      {/* INFO BOX */}
      <div className="px-4 sm:px-[5%] py-12 bg-gradient-to-b from-gray-50 to-white">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-[#1a1a4e] mb-8 text-center" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
            Avantages YOUMMA JOBS
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              { icon: '👥', title: 'Visibilité', desc: 'Profil visible par tous les clients de Guinée' },
              { icon: '⭐', title: 'Réputation', desc: 'Système d\'avis pour construire votre crédibilité' },
              { icon: '📊', title: 'Tableau de bord', desc: 'Suivi complet de vos performances' },
              { icon: '💬', title: 'Contact direct', desc: 'WhatsApp et téléphone sans intermédiaire' },
              { icon: '✓', title: 'Vérification', desc: 'Badge Artisan Vérifié pour plus de confiance' },
              { icon: '💰', title: 'Tarif accessible', desc: '50 000 GNF/mois pour booster votre visibilité' },
            ].map((item, idx) => (
              <div key={idx} className="bg-white border border-gray-200 rounded-xl p-6">
                <div className="text-3xl mb-3">{item.icon}</div>
                <h3 className="font-bold text-[#1a1a4e] mb-2">{item.title}</h3>
                <p className="text-sm text-gray-600">{item.desc}</p>
              </div>
            ))}
          </div>
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
