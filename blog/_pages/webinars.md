---
title: "AKS - Community Calls"
layout: splash
classes:
  - page--webinars

permalink: /webinars/
date: 2024-12-17T11:48:41-04:00
# Add reference to the webinars.scss file
custom_css:
  - webinars
header:
  overlay_image: /assets/webinars/AKS-CommunityCalls-Banner.png
  excerpt: "Azure Kubernetes Service"
  actions:
    - label: "Past Call Recordings"
      url: "https://www.youtube.com/playlist?list=PLc3Ep462vVYu0eMSiORonzj3utqYu285z"

# Custom CSS to set background color to white
header-includes: |
  <style>
    body {
      background-color: white !important;
    }
    .page__hero--overlay .page__title,
    .page__hero--overlay .page__meta,
    .page__hero--overlay .page__lead,
    .page__hero--overlay .btn {
      color: inherit;
    }
  </style>


intro: 
  - excerpt: "Welcome to the AKS Community Calls! These sessions foster direct interaction between our product teams and the AKS community. Engage with our teams, hear the latest updates, and gain insights into the product’s development. Join our monthly public calls to discuss the product roadmap, provide feedback, and learn from others’ experiences with AKS. Check out the <a href='https://github.com/orgs/Azure/projects/685/views/1' style='color:white'>public feature roadmap</a> for details on features in development, public preview, and general availability."

agendarow1:
  - title: "Agenda (June 2025)"
    excerpt: "<ul>
                <li>Announcements:
                  <ul>
                    <li>AKS Labs on Microsoft Reactor</li>
                    <li>Cost Management Video Series</li>
                  </ul>
                </li>
                <li>Community Content Showcase</li><br>
                <li>Deprecated Features</li><br>
                <li>Feature Deepdive:
                  <ul><li>Cost Management (Kaysie Yu)</li></ul>
                </li>
              <li>Feature Roadmap (GA, Preview & In Progress)</li></ul>"
    notice: notice--info


timezones1:
  - title: "Americas & Europe"
    image_path: /assets/webinars/community calls - Image- Americas.png
    excerpt: "Every 3rd Wednesday of the month. <br>
          8 AM PST <br>
          3 PM GMT <br>
          <a HREF='../assets/webinars/Recurring-AKS Community Roadmap Call.ics'>Add to my calendar</a><br>"
    btn_label: "Join Now - <br>Americas & Europe"
    btn_class: "btn--primary"
    url: 'https://aka.ms/aks/communitycalls-us/roadmap/joinnow'
    notice: notice--info
    style: { .border-width: 1px .border-color:#fff }

  - title: "Australia/NZ, India, Asia Pacific"
    image_path: /assets/webinars/community calls - Image- APAC.png
    excerpt: "Every 4th Wednesday of the month. <br>
          10:30 AM IST <br>
          3:00 PM AEST <br>
          <a HREF='../assets/webinars/AKS Community Roadmap Call-APAC.ics'>Add to my calendar</a><br>"
    btn_label: "Join Now - Australia/NZ, India, Asia Pacific"
    btn_class: "btn--primary"
    url: 'https://aka.ms/aks/communitycalls-apac/roadmap/joinnow'

---
{% include feature_row id="intro" type="justified" %}
{% include feature_row id="agendarow1" type="justified" %}
<div class="timezone-cards-container">
{% include feature_row id="timezones1" %}
</div>
