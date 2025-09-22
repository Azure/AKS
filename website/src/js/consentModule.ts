import { setDefaultConsent, updateConsentStatus, loadGoogleAnalytics } from '../utils/analytics';

// This module runs on the client side to handle Google Analytics consent
export default function clientModule() {
  // Set default consent to denied
  setDefaultConsent();

  // Check if user has previously given consent
  const consentGranted = localStorage.getItem('consentGranted');
  if (consentGranted === 'true') {
    // Load Google Analytics and update consent if previously granted
    updateConsentStatus(true);
    loadGoogleAnalytics();
  }
}