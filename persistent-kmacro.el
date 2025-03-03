;;; persistent-kmacro.el --- Store your named macros persistently!           -*- lexical-binding: t; -*-

;; Copyright (C) 2023 Artur Yaroshenko

;; Author: Artur Yaroshenko <artawower@protonmail.com>
;; URL: https://github.com/artawower/persistent-kmacro.el
;; Package-Requires: ((emacs "28.1") (persistent-soft "0.8.10"))
;; Version: 0.0.5

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; Package for organizing and executing named kbd macros.

;;; Code:

(require 'subr-x)
(require 'persistent-soft)

(defcustom persistent-kmacro-macro-file "persistent-kmacro.el"
  "File where macros are stored."
  :type 'string
  :group 'persistent-kmacro)

(defcustom persistent-kmacro--include-projectile-name t
  "If non-nil, include projectile project name in macro name."
  :type 'boolean
  :group 'persistent-kmacro)

(defvar persistent-kmacro--named-functions '()
  "List of macro names.")

(defvar persistent-kmacro--tmp-buffer "*elmacro-tmp*"
  "Temporary buffer for storing macros.")


(defun persistent-kmacro--build-prefix-name ()
  "Build prefix name for macro."
  (if (and persistent-kmacro--include-projectile-name (fboundp 'projectile-project-name))
      (format "[%s] " (projectile-project-name))
    ""))

(defun persistent-kmacro-restore-sesstion ()
  "Restore macros from `persistent-kmacro-macro-file'."
  (interactive)
  (setq persistent-kmacro--named-functions
        (persistent-soft-fetch 'persistent-kmacro-named-functions persistent-kmacro-macro-file)))

(defun persistent-kmacro-save-session ()
  "Save macros to `persistent-kmacro-macro-file'."
  (interactive)
  (persistent-soft-store 'persistent-kmacro-named-functions persistent-kmacro--named-functions persistent-kmacro-macro-file))

(defun persistent-kmacro--restore-session-when-no-data ()
  "Restore session when `persistent-kmacro--named-functions' is empty."
  (ignore-errors (unless persistent-kmacro--named-functions
                   (persistent-kmacro-restore-sesstion))))

;;;###autoload
(defun persistent-kmacro-name-last-kbd-macro (name)
  "Name last kbd macro.
NAME is the name of the macro."
  (interactive (list (read-string "Name for last kbd macro: " (persistent-kmacro--build-prefix-name))))
  (persistent-kmacro--restore-session-when-no-data)
  (name-last-kbd-macro (intern name))
  (let ((kbd-macro (with-current-buffer (get-buffer-create persistent-kmacro--tmp-buffer)
                     (insert-kbd-macro (intern name))
                     (buffer-string))))
    (kill-buffer persistent-kmacro--tmp-buffer)

    (add-to-list 'persistent-kmacro--named-functions `(,name . ,kbd-macro))
    (persistent-kmacro-save-session)))

;;;###autoload
(defun persistent-kmacro-execute-macro ()
  "Execute macros."
  (interactive)
  (persistent-kmacro--restore-session-when-no-data)
  (let ((macro-name (completing-read "Execute macro: " persistent-kmacro--named-functions nil t)))
    (unless (fboundp (intern macro-name))
      (eval (car (read-from-string (cdr (assoc macro-name persistent-kmacro--named-functions))))))
    (call-interactively (intern macro-name))
    (message "macto wacro: %s" (intern macro-name))
    ))

;;;###autoload
(defun persistent-kmacro-apply ()
  "Apply macro depend on current state."
  (interactive)
  (if (use-region-p)
      (persistent-kmacro-apply-macro-to-region-lines)
    (persistent-kmacro-execute-macro)))

;;;###autoload
(defun persistent-kmacro-apply-macro-to-region-lines ()
  "Execute macros to each line in region."
  (interactive)
  (persistent-kmacro--restore-session-when-no-data)
  (let ((macro-name (persistent-kmacro--select-macro)))
    (persistent-kmacro--do-lines (lambda () (call-interactively (intern macro-name))))))


(defun persistent-kmacro--do-lines (fun)
  "Invoke function FUN on the text of each line from START to END."
  (let ((start (if (use-region-p) (region-beginning) (point-min)))
        (end (if (use-region-p) (region-end) (point-max))))
    (save-excursion
      (goto-char start)
      (while (< (point) end)
        (funcall fun)
        (forward-line 1)))))

(defun persistent-kmacro--select-macro ()
  "Select macro from completion list."
  (let ((macro-name (completing-read "Execute macro: " persistent-kmacro--named-functions nil t)))
    (unless (fboundp (intern macro-name))
      (eval (car (read-from-string (cdr (assoc macro-name persistent-kmacro--named-functions))))))
    macro-name))

;;;###autoload
(defun persistent-kmacro-remove-macro ()
  "Remove macro."
  (interactive)
  (persistent-kmacro--restore-session-when-no-data)
  (let ((macro (completing-read "Remove macro: " persistent-kmacro--named-functions nil t)))
    (setq persistent-kmacro--named-functions (delete (assoc macro persistent-kmacro--named-functions) persistent-kmacro--named-functions))
    (persistent-kmacro-save-session)))


(provide 'persistent-kmacro)

;;; persistent-kmacro.el ends here
