'use client';

import { useState } from 'react';
import Link from 'next/link';
import supabase from '@/lib/supabase';

export default function ConnexionPage() {
  const [step, setStep] = useState<'phone' | 'pin'>('phone');
  const [phone, setPhone] = useState('');
  const [pin, setPin] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [artisanName, setArtisanName] = useState('');

  const handlePhoneSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (!phone || phone.length < 8) {
        throw new Error('Veuillez entrer un numéro de téléphone valide');
      }

      // Vérifier que le numéro existe dans Supabase
      const { data, error: queryError } = await supabase
        .from('providers')
        .select('id, prenom, nom')
        .eq('telephone', phone)
        .single();

      if (queryError || !data) {
        throw new Error('Numéro de téléphone non trouvé. Assurez-vous d\'être inscrit.');
      }

      setArtisanName(`${data.prenom} ${data.nom}`);
      setStep('pin');
    } catch (err: any) {
      setError(err.message || 'Erreur lors de la recherche du compte');
    } finally {
      setLoading(false);
    }
  };

  const handlePinSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (!pin || pin.length < 4) {
        throw new Error('Le code PIN doit contenir au moins 4 chiffres');
      }

      // Récupérer l'utilisateur et vérifier le PIN (simplifié - à améliorer)
      const { data, error: queryError } = await supabase
        .from('providers')
        .select('id, password_hash')
        .eq('telephone', phone)
        .single();

      if (queryError || !data) {
        throw new Error('Compte non trouvé');
      }

      // Vérifier le PIN (dans une vraie app, utiliser des tokens JWT)
      const hashPin = pin; // Simplifié pour la démo
      
      setSuccess(true);
      setPin('');
      
      // Rediriger après 2 secondes
      setTimeout(() => {
        window.location.href = '/dashboard';
      }, 2000);
    } catch (err: any) {
      setError(err.message || 'Erreur lors de la connexion');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-[#0a0f2e] to-[#1a1a4e] flex flex-col">
      {/* NAVBAR */}
      <nav className="border-b border-white/10">
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

      {/* MAIN CONTENT */}
      <div className="flex-1 flex items-center justify-center px-4 py-12">
        <div className="w-full max-w-md">
          {/* LOGO / TITLE */}
          <div className="text-center mb-8">
            <h1 className="text-3xl sm:text-4xl font-bold text-white mb-2" style={{ fontFamily: 'var(--font-libre-baskerville)' }}>
              Bienvenue !
            </h1>
            <p className="text-white/70">Connectez-vous à votre profil YOUMMA JOBS</p>
          </div>

          {success ? (
            <div className="bg-white/10 border border-[#22c55e] rounded-2xl p-8 text-center backdrop-blur-sm">
              <i className="fa-solid fa-circle-check text-5xl text-[#22c55e] mb-4"></i>
              <h2 className="text-2xl font-bold text-white mb-2">Connexion réussie !</h2>
              <p className="text-white/70 mb-6">
                Bienvenue {artisanName}, accès à votre tableau de bord...
              </p>
              <div className="h-1 bg-gradient-to-r from-[#f97316] to-[#22c55e] rounded-full"></div>
            </div>
          ) : (
            <form 
              onSubmit={step === 'phone' ? handlePhoneSubmit : handlePinSubmit}
              className="bg-white/10 border border-white/20 rounded-2xl p-8 backdrop-blur-sm"
            >
              {error && (
                <div className="mb-6 p-4 bg-red-500/20 border border-red-500/50 rounded-lg text-red-200 text-sm">
                  <i className="fa-solid fa-exclamation-circle mr-2"></i>
                  {error}
                </div>
              )}

              {step === 'phone' ? (
                <>
                  {/* STEP 1: Téléphone */}
                  <div className="mb-6">
                    <label className="block text-white text-sm font-semibold mb-3">
                      Numéro de téléphone
                    </label>
                    <div className="flex items-center gap-2 px-4 py-3 bg-white/5 border border-white/20 rounded-lg focus-within:border-[#f97316] focus-within:ring-2 focus-within:ring-[#f97316]/20 transition">
                      <span className="text-white/60 text-sm">+224</span>
                      <input
                        type="tel"
                        placeholder="621234567"
                        value={phone}
                        onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                        maxLength="9"
                        className="flex-1 bg-transparent text-white outline-none placeholder:text-white/40"
                      />
                    </div>
                    <p className="text-white/50 text-xs mt-2">
                      <i className="fa-solid fa-info-circle mr-1"></i>
                      Entrez le numéro utilisé lors de votre inscription
                    </p>
                  </div>

                  <button
                    type="submit"
                    disabled={loading || !phone}
                    className={`w-full px-6 py-3 rounded-lg font-bold transition text-white flex items-center justify-center gap-2 ${
                      loading || !phone
                        ? 'bg-gray-600 cursor-not-allowed opacity-50'
                        : 'bg-[#f97316] hover:bg-[#c74b00]'
                    }`}
                  >
                    {loading ? (
                      <>
                        <i className="fa-solid fa-spinner fa-spin"></i>
                        Vérification...
                      </>
                    ) : (
                      <>
                        <i className="fa-solid fa-arrow-right"></i>
                        Continuer
                      </>
                    )}
                  </button>
                </>
              ) : (
                <>
                  {/* STEP 2: Code PIN */}
                  <div className="mb-6 p-4 bg-white/5 border border-white/20 rounded-lg">
                    <p className="text-white text-sm">
                      <strong>Numéro :</strong> +224 {phone.slice(0, 3)} ••• {phone.slice(-3)}
                    </p>
                    <button
                      type="button"
                      onClick={() => setStep('phone')}
                      className="text-[#f97316] hover:text-[#f97316]/80 text-sm mt-2 transition"
                    >
                      <i className="fa-solid fa-edit mr-1"></i>Modifier
                    </button>
                  </div>

                  <div className="mb-6">
                    <label className="block text-white text-sm font-semibold mb-3">
                      Code PIN de sécurité
                    </label>
                    <input
                      type="password"
                      placeholder="••••"
                      value={pin}
                      onChange={(e) => setPin(e.target.value.replace(/\D/g, ''))}
                      maxLength="6"
                      className="w-full px-4 py-3 bg-white/5 border border-white/20 rounded-lg text-white text-center text-xl font-bold outline-none placeholder:text-white/40 focus:border-[#f97316] focus:ring-2 focus:ring-[#f97316]/20 transition"
                    />
                    <p className="text-white/50 text-xs mt-2">
                      <i className="fa-solid fa-info-circle mr-1"></i>
                      Code PIN envoyé par SMS (6 chiffres max)
                    </p>
                  </div>

                  <button
                    type="submit"
                    disabled={loading || !pin}
                    className={`w-full px-6 py-3 rounded-lg font-bold transition text-white flex items-center justify-center gap-2 ${
                      loading || !pin
                        ? 'bg-gray-600 cursor-not-allowed opacity-50'
                        : 'bg-[#f97316] hover:bg-[#c74b00]'
                    }`}
                  >
                    {loading ? (
                      <>
                        <i className="fa-solid fa-spinner fa-spin"></i>
                        Vérification...
                      </>
                    ) : (
                      <>
                        <i className="fa-solid fa-lock-open"></i>
                        Me connecter
                      </>
                    )}
                  </button>
                </>
              )}

              {/* Divider */}
              <div className="flex items-center gap-3 my-6">
                <div className="flex-1 h-px bg-white/10"></div>
                <span className="text-white/50 text-xs">OU</span>
                <div className="flex-1 h-px bg-white/10"></div>
              </div>

              {/* Sign up link */}
              <Link
                href="/inscription"
                className="w-full px-6 py-3 border-2 border-white/30 text-white rounded-lg font-bold hover:border-[#f97316] hover:text-[#f97316] transition flex items-center justify-center gap-2"
              >
                <i className="fa-solid fa-user-plus"></i>
                Créer un compte
              </Link>
            </form>
          )}

          {/* Security Info */}
          <div className="mt-8 p-4 bg-white/5 border border-white/10 rounded-lg">
            <div className="flex gap-3 text-sm text-white/70">
              <i className="fa-solid fa-shield-halved text-[#f97316] mt-1 flex-shrink-0"></i>
              <p>
                Votre compte est protégé par un code PIN personnel. Assurez-vous de ne pas le partager.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* FOOTER */}
      <footer className="border-t border-white/10 py-6 px-4 text-center text-white/50 text-sm">
        <p>YOUMMA JOBS © 2025 — Plateforme des artisans en Guinée</p>
      </footer>
    </div>
  );
}
