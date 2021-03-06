;;; lang/clojure/config.el

(def-package! clojure-mode
  :mode "\\.clj$")

(def-package! cider
  :commands (cider-jack-in cider-mode)
  :config
  (setq
   nrepl-hide-special-buffers t))
