import React from 'react';
import { faSun } from '@fortawesome/free-solid-svg-icons';
import type { Props } from '@theme/Icon/LightMode';
import ThemeIcon from '@site/src/components/ThemeIcon';

export default function IconLightMode(props: Props) {
  return <ThemeIcon icon={faSun} {...props} />;
}
