import React from 'react';
import { faMoon } from '@fortawesome/free-solid-svg-icons';
import type { Props } from '@theme/Icon/DarkMode';
import ThemeIcon from '@site/src/components/ThemeIcon';

export default function IconDarkMode(props: Props) {
  return <ThemeIcon icon={faMoon} {...props} />;
}
