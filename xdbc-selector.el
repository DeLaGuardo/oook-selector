(require 'xdmp-methods)
(provide 'xdbc-selector)

;;;; xdbc selector

;; based on slime-selector, a.k.a. Slime's Buffer selector
;; see: https://github.com/slime/slime/blob/master/slime.el

;;;; License and Commentary

;;     Copyright (C) 2003  Eric Marsden, Luke Gorrie, Helmut Eller
;;     Copyright (C) 2004,2005,2006  Luke Gorrie, Helmut Eller
;;     Copyright (C) 2007,2008,2009  Helmut Eller, Tobias C. Rittweiler
;;     Copyright (C) 2016  Max-Gerd Retzlaff
;;
;;     For a detailed list of contributors, see the manual.
;;
;;     This program is free software; you can redistribute it and/or
;;     modify it under the terms of the GNU General Public License as
;;     published by the Free Software Foundation; either version 2 of
;;     the License, or (at your option) any later version.
;;
;;     This program is distributed in the hope that it will be useful,
;;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;;     GNU General Public License for more details.
;;
;;     You should have received a copy of the GNU General Public
;;     License along with this program; if not, write to the Free
;;     Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
;;     MA 02111-1307, USA.


(defvar xdbc-selector-methods nil
  "List of buffer-selection methods for the `xdbc-select' command.
Each element is a list (KEY DESCRIPTION FUNCTION).
DESCRIPTION is a one-line description of what the key selects.")

(defvar xdbc-selector-other-window nil
  "If non-nil use switch-to-buffer-other-window.")

(defun xdbc-selector (&optional other-window)
  "Select a new buffer by type, indicated by a single character.
The user is prompted for a single character indicating the method by
which to choose a new buffer. The `?' character describes the
available methods.

See `def-xdbc-selector-method' for defining new methods."
  (interactive)
  (message "Select [%s]: "
           (apply #'string (mapcar #'car xdbc-selector-methods)))
  (let* ((xdbc-selector-other-window other-window)
         (ch (save-window-excursion
               (select-window (minibuffer-window))
               (read-char)))
         (method (cl-find ch xdbc-selector-methods :key #'car)))
    (cond (method
           (funcall (cl-third method)))
          (t
           (message "No method for character: ?\\%c" ch)
           (ding)
           (sleep-for 1)
           (discard-input)
           (xdbc-selector)))))

(defmacro def-xdbc-selector-method (key description &rest body)
  "Define a new `xdbc-select' buffer selection method.

KEY is the key the user will enter to choose this method.

DESCRIPTION is a one-line sentence describing how the method
selects a buffer.

BODY is a series of forms which are evaluated when the selector
is chosen. The returned buffer is selected with
switch-to-buffer."
  (let ((method `(lambda ()
                   ,@body)))
    `(setq xdbc-selector-methods
           (cl-sort (cons (list ,key ,description ,method)
                          (cl-remove ,key xdbc-selector-methods :key #'car))
                    #'< :key #'car))))

(def-xdbc-selector-method ?? "Selector help buffer."
  (ignore-errors (kill-buffer "*Select Help*"))
  (with-current-buffer (get-buffer-create "*Select Help*")
    (insert "Select Methods:\n\n")
    (cl-loop for (key line nil) in xdbc-selector-methods
             do (insert (format "%c:\t%s\n" key line)))
    (goto-char (point-min))
    (help-mode)
    (display-buffer (current-buffer) t))
  (xdbc-selector)
  (current-buffer))

(cl-pushnew (list ?4 "Select in other window" (lambda () (xdbc-selector t)))
            xdbc-selector-methods :key #'car)

(def-xdbc-selector-method ?q "Abort."
  (top-level))


;;; custom methods

(def-xdbc-selector-method ?q
  "evaluate a query from minibuffer"
  (call-interactively 'cider-any-string))


(def-xdbc-selector-method ?s
  "show document"
  (call-interactively 'xdmp-show))

(def-xdbc-selector-method ?S
  "show document to other db"
  (setq current-prefix-arg '(4)) ; C-u
  (call-interactively 'xdmp-show))


(def-xdbc-selector-method ?l
  "list documents"
  (call-interactively 'xdmp-list-documents))

(def-xdbc-selector-method ?L
  "list documents to other db"
  (setq current-prefix-arg '(4)) ; C-u
  (call-interactively 'xdmp-list-documents))


(def-xdbc-selector-method ?u
  "upload a document"
  (call-interactively 'xdmp-document-load))

(def-xdbc-selector-method ?U
  "upload a document to other db"
  (setq current-prefix-arg '(4)) ; C-u
  (call-interactively 'xdmp-document-load))


(def-xdbc-selector-method ?d
  "delete a document"
  (call-interactively 'xdmp-document-delete))

(def-xdbc-selector-method ?D
  "delete a document to other db"
  (setq current-prefix-arg '(4)) ; C-u
  (call-interactively 'xdmp-document-delete))
