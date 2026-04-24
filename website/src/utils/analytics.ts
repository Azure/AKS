// Centralized configuration for Google Analytics
export const GA_CONFIG = {
  trackingId: '<GTAG_ID>',
  anonymizeIP: true,
} as const;

// Global gtag types
declare global {
  interface Window {
    dataLayer?: any[];
    gtag?: (...args: any[]) => void;
  }
}

// Utility functions for Google Analytics
export const initializeGtag = () => {
  window.dataLayer = window.dataLayer || [];
  function gtag(...args: any[]) {
    window.dataLayer?.push(arguments);
  }
  window.gtag = gtag;
  return gtag;
};

export const setDefaultConsent = () => {
  const gtag = initializeGtag();
  gtag('consent', 'default', {
    'ad_user_data': 'denied',
    'ad_personalization': 'denied',
    'ad_storage': 'denied',
    'analytics_storage': 'denied',
    'wait_for_update': 500,
  });
};

export const updateConsentStatus = (granted: boolean) => {
  const gtag = initializeGtag();
  gtag('consent', 'update', {
    ad_user_data: granted ? 'granted' : 'denied',
    ad_personalization: granted ? 'granted' : 'denied',
    ad_storage: granted ? 'granted' : 'denied',
    analytics_storage: granted ? 'granted' : 'denied'
  });
};

export const loadGoogleAnalytics = () => {
  // Load gtag.js script
  const script = document.createElement('script');
  script.async = true;
  script.src = `https://www.googletagmanager.com/gtag/js?id=${GA_CONFIG.trackingId}`;
  document.head.appendChild(script);

  // Initialize gtag
  const gtag = initializeGtag();
  gtag('js', new Date());
  gtag('config', GA_CONFIG.trackingId, {
    anonymize_ip: GA_CONFIG.anonymizeIP
  });
};