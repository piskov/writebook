# Russian interface

The application interface is Russian. Existing multilingual help popovers,
the empty-book instructions, and the unsupported-browser page retain their
other languages and include Russian. Book titles and authored content are
not translated or rewritten.

Most interface labels are literals in the views and helpers, following the
existing application structure. Rails-generated names, validation messages,
word counts, and relative times use `config/locales/ru.yml`. The Russian
pluralization rule is loaded from `config/locales/ru.rb`, including after an
I18n reload. Relative-time forms are intended for the revision history's
trailing “назад”.

The vendored `vendor/javascript/house.min.js` has localized UI strings for
its fallback toolbar, required-field validation, and uploads. Preserve those
translations when updating House; the current version has no locale API.
The application toolbar also supplies explicit Russian titles.

This change needs no migration or reindex. Deploy the new Docker image with
the existing storage volume and environment settings. Native browser and OS
dialogs use the browser or OS language.
