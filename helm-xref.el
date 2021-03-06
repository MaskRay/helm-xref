;;; helm-xref.el --- Helm interface for xref results -*- lexical-binding: t -*-

;; Copyright (C) 2017  Fritz Stelzer <brotzeitmacher@gmail.com>

;; Author: Fritz Stelzer <brotzeitmacher@gmail.com>
;; URL: https://github.com/brotzeitmacher/helm-xref
;; Version: 0.2
;; Package-Requires: ((emacs "25.1") (helm "1.9.4"))

;;; License:
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;;; Code:

(require 'helm)
(require 'xref)
(require 'cl-seq)

(defvar helm-xref-alist nil
  "Holds helm candidates.")

(defgroup helm-xref nil
  "Xref with helm."
  :prefix "helm-xref-" :group 'helm)

(defface helm-xref-file-name
  '((t (:foreground "cyan")))
  "Face for xref file name"
  :group 'helm-xref)

(defface helm-xref-line-number
  '((t (:inherit 'compilation-line-number)))
  "Face for xref line number"
  :group 'helm-xref)

(defun helm-xref-candidates (xrefs)
  "Convert XREF-ALIST items to helm candidates and add them to `helm-xref-alist'."
  (dolist (xref xrefs)
    (with-slots (summary location) xref
      (let* ((line (xref-location-line location))
             (marker (xref-location-marker location))
             (file (xref-location-group location))
             candidate)
        (setq candidate
              (concat
               (propertize (car (reverse (split-string file "\\/")))
                           'font-lock-face 'helm-xref-file-name)
               (when (string= "integer" (type-of line))
                 (concat
                  ":"
                  (propertize (int-to-string line)
                              'font-lock-face 'helm-xref-line-number)))
               ":"
               summary))
        (push `(,candidate . ,marker) helm-xref-alist)))))

(defun helm-xref-goto-location (location func)
  "Set buffer and point according to xref-location LOCATION.

Use FUNC to display buffer."
  (let ((buf (marker-buffer location))
        (offset (marker-position location)))
    (with-current-buffer buf
      (goto-char offset)
      (funcall func buf))))

(defun helm-xref-source ()
  "Return a `helm' source for xref results."
  (helm-build-sync-source "Helm Xref"
    :candidates (lambda ()
                  helm-xref-alist)
    :persistent-action (lambda (candidate)
                         (helm-xref-goto-location candidate 'display-buffer))
    :action (lambda (candidate)
              (helm-xref-goto-location candidate 'switch-to-buffer))
    :candidate-transformer (lambda (candidates)
                             (let (group
                                   result)
                               (cl-loop for x in (reverse (cl-sort candidates #'string-lessp :key #'car))
					do (cond
					    ((or (= (length group) 0)
						 (string= (nth 0 (split-string (car x) ":"))
							  (nth 0 (split-string (car (nth -1 group)) ":"))))
					     (push x group))
					    (t
					     (dolist (xref (cl-sort group #'> :key #'cdr))
					       (push xref result))
					     (setq group nil)
					     (push x group)))
					finally (when (> (length group) 0)
						  (dolist (xref (cl-sort group #'> :key #'cdr))
						    (push xref result))))
                               result))
    :candidate-number-limit 9999))

(defun helm-xref-show-xrefs (xrefs _alist)
  "Function to display XREFS.

Needs to be set the value of `xref-show-xrefs-function'."
  (setq helm-xref-alist nil)
  (helm-xref-candidates xrefs)
  (helm :sources (helm-xref-source)
        :truncate-lines t
        :buffer "*helm-xref*"))

(provide 'helm-xref)
;;; helm-xref.el ends here
