import React, { type SVGProps } from 'react';
import type { IconDefinition } from '@fortawesome/fontawesome-svg-core';

type Props = SVGProps<SVGSVGElement> & { icon: IconDefinition };

export default function ThemeIcon({ icon, ...props }: Props) {
  const [width, height, , , paths] = icon.icon;
  return (
    <svg width={20} height={20} {...props} style={{ overflow: 'visible', ...props.style }} viewBox={`0 0 ${width} ${height}`}>
      <path fill="currentColor" d={typeof paths === 'string' ? paths : paths.join(' ')} />
    </svg>
  );
}
