import React, { useState, useEffect } from "react";
import { updateConsentStatus, loadGoogleAnalytics } from "../utils/analytics";
import "./CookieConsent.css";

const CookieConsent: React.FC = () => {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // Check if consent has already been given or denied
    const consentGranted = localStorage.getItem("consentGranted");
    if (!consentGranted) {
      setIsVisible(true);
    } else if (consentGranted === "true") {
      // If consent was previously granted, update gtag consent
      updateConsentStatus(true);
    }
  }, []);

  const handleAccept = () => {
    localStorage.setItem("consentGranted", "true");
    updateConsentStatus(true);
    loadGoogleAnalytics();
    setIsVisible(false);
  };

  const handleReject = () => {
    localStorage.setItem("consentGranted", "false");
    updateConsentStatus(false);
    setIsVisible(false);
  };

  if (!isVisible) {
    return null;
  }

  return (
    <div className="cookie-consent-banner">
      <div className="cookie-consent-content">
        <div className="cookie-consent-text">
          We use cookies and similar technologies to understand site usage and
          provide you with the best experience. By clicking "Accept", you
          consent to the use of cookies for analytics purposes.
        </div>
        <div className="cookie-consent-buttons">
          <button
            className="cookie-consent-button cookie-consent-button--accept"
            onClick={handleAccept}
          >
            Accept
          </button>
          <button
            className="cookie-consent-button cookie-consent-button--reject"
            onClick={handleReject}
          >
            Reject
          </button>
        </div>
      </div>
    </div>
  );
};

export default CookieConsent;
