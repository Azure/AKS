import React from "react";
import CookieConsent from "../../components/CookieConsent";

// Docusaurus Root component to add global elements
export default function Root({ children }: { children: React.ReactNode }) {
  return (
    <>
      {children}
      <CookieConsent />
    </>
  );
}
