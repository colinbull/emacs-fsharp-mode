;;; fsharp-doc.el -- show information for F# symbol at point.
;;
;; Filename: fsharp-doc.el
;; Author: Chris Barrett <chris.d.barrett@me.com>
;; Maintainer: Chris Barrett <chris.d.barrett@me.com>
;; Keywords: fsharp, languages
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;; Commentary:
;;
;; This is part of fsharp-mode for Emacs. It communicates with the F#
;; completion process to provide information for the symbol at point.
;;
;; This should be loaded automatically by fsharp-mode. Otherwise, add
;; this file to your load path, then call
;;
;;   (autoload 'turn-on-fsharp-doc-mode "fsharp-doc.el")
;;   (add-hook 'fsharp-mode-hook 'turn-on-fsharp-doc-mode)
;;
;;; Code:

(with-no-warnings (require 'cl))
(require 'fsharp-mode-completion)

(declare-function fsharp-mode "fsharp-mode.el")
(defvar fsharp-doc-idle-delay 0.5
  "The number of seconds to wait for input idle before showing a tooltip.")

(define-minor-mode fsharp-doc-mode
  "Display F# documentation in the minibuffer."
  nil
  ""
  nil
  ;; Body
  (fsharp-doc-reset-timer)
  (when fsharp-doc-mode
    (fsharp-doc-start-timer)
    (run-hooks 'fsharp-doc-mode-hook))
  fsharp-doc-mode)

(defun turn-on-fsharp-doc-mode ()
  (fsharp-doc-mode t))

(defun turn-off-fsharp-doc-mode ()
  (fsharp-doc-mode nil))

;;; -----------------------------------------------------------------------------

(defvar fsharp-doc-timer nil)

(defun fsharp-doc-start-timer ()
  (unless fsharp-doc-timer
    (setq fsharp-doc-timer
          (run-with-idle-timer fsharp-doc-idle-delay t
                               'fsharp-doc--request-info))))

(defun fsharp-doc-reset-timer ()
  (when fsharp-doc-timer
    (cancel-timer fsharp-doc-timer)
    (setq fsharp-doc-timer nil)))

(defvar fsharp-doc-buffer-name "* fsharp-doc-buffer *")
(defun fsharp-get-fontification-buffer ()
  (let ((buffer (get-buffer fsharp-doc-buffer-name)))
    (if (buffer-live-p buffer)
        buffer
      (with-current-buffer (generate-new-buffer fsharp-doc-buffer-name)
        (ignore-errors
          (let ((fsharp-mode-hook nil))
            (fsharp-mode)))
        (current-buffer)))))

(defun fsharp-fontify-string (str)
  (with-current-buffer (fsharp-get-fontification-buffer)
    (delete-region (point-min) (point-max))
    (font-lock-fontify-region (point) (progn (insert str ";") (point)))
    (buffer-substring (point-min) (1- (point-max)))))
;;; ----------------------------------------------------------------------------

(defun fsharp-doc/format-for-minibuffer (str)
  "Parse the result from the F# process."
  (destructuring-bind (x &rest xs) (split-string str "[\r\n]")
    (let ((line (if (string-match-p "^Multiple" x) (car-safe xs) x))
          (name (fsharp-doc-extract-full-name str)))
      (fsharp-fontify-string
       (fsharp-doc-tidy-result
        (cond
         ;; Don't fully-qualify let-bindings.
         ((string-match-p "^val" line)
          line)

         ;; Extract type identifier.
         (name
          (fsharp-doc-replace-identifier line name))

         (t
          line)))))))

(defun fsharp-doc-extract-full-name (str)
  (when (string-match "Full name: \\(.*\\)$" str)
    (match-string 1 str)))

(defun fsharp-doc-replace-identifier (str fullname)
  (replace-regexp-in-string
   "^\\w+ \\(public \\|private \\|internal \\)?\\(.*?\\) "
   fullname str 'fixcase "\2" 2))

(defun fsharp-doc-tidy-result (str)
  (replace-regexp-in-string "[ ]*=[ ]*" "" str))

;;; ----------------------------------------------------------------------------

(defvar fsharp-doc-prevpoint nil)

(defun fsharp-doc--request-info ()
  "Send a request for tooltip and usage information unless at an error."
  (interactive)
  (let ((in-usage-overlay (fsharp-ac/usage-overlay-at (point))))
    (unless in-usage-overlay
      (fsharp-ac--clear-symbol-uses))
    (when (and fsharp-doc-mode
               (thing-at-point 'symbol)
               (not (eq (char-after) ? )))
      (unless (or (equal (point) fsharp-doc-prevpoint)
                  (not (eq fsharp-ac-status 'idle))
                  executing-kbd-macro
                  (fsharp-ac/error-overlay-at (point))
                  (active-minibuffer-window)
                  cursor-in-echo-area)
        (setq fsharp-doc-prevpoint (point))
        (fsharp-ac/show-typesig-at-point t)
        (unless in-usage-overlay
          (fsharp-ac/symboluse-at-point))))))

(provide 'fsharp-doc)

;;; fsharp-doc.el ends here
