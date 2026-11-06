import React from 'react';
import { faCircleHalfStroke } from '@fortawesome/free-solid-svg-icons';
import type { Props } from '@theme/Icon/SystemColorMode';
import ThemeIcon from '@site/src/components/ThemeIcon';

export default function IconSystemColorMode(props: Props) {
  return <ThemeIcon icon={faCircleHalfStroke} {...props} />;
}
