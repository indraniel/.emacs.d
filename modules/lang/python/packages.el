;; -*- no-byte-compile: t; -*-
;;; lang/python/packages.el

;; requires: python jedi setuptools

(package! company-jedi)
(package! nose)
(package! pip-requirements)

(when (featurep! :completion company)
  (package! company-jedi))
