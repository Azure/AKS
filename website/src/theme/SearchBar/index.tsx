import React, { type CSSProperties } from 'react';
import { icon } from '@fortawesome/fontawesome-svg-core';
import { faMagnifyingGlass } from '@fortawesome/free-solid-svg-icons';
import OriginalSearchBar from '@theme-original/SearchBar';

const searchSvg = icon(faMagnifyingGlass, {
  attributes: { xmlns: 'http://www.w3.org/2000/svg' },
}).html.join('');
const searchIcon = `url("data:image/svg+xml,${encodeURIComponent(searchSvg)}")`;
const style: CSSProperties & { '--search-trigger-icon': string } = {
  display: 'contents',
  '--search-trigger-icon': searchIcon,
};

export default function SearchBar() {
  return (
    <div style={style}>
      <OriginalSearchBar />
    </div>
  );
}
