# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/lib", under: "lib"
pin "stimulus-color-picker"
pin "@simonwep/pickr", to: "@simonwep--pickr.js"
pin "stimulus-textarea-autogrow"
pin "sortablejs" # @1.15.7
pin "hls.js" # @1.7.2
