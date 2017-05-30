(require 'xquery-mode)
(require 'oook)
(require 'cider-eval-form)
(require 'oook-list-mode)

;;;; xdmp interface functions to query for databases

(defun xdmp-get-current-database ()
  ;; should be the same as in variable 'oook-content-base'
  (car (oook-eval-sync "xdmp:database-name(xdmp:database())")))

(defun xdmp-get-default-database ()
  (car (oook-eval-sync "xdmp:database-name(xdmp:server-database(xdmp:server()))")))

(defun xdmp-get-modules-database ()
  (car (oook-eval-sync "xdmp:database-name(xdmp:modules-database())")))

(defun xdmp-get-databases ()
  (oook-eval-sync "for $d in xdmp:databases() return xdmp:database-name($d)"))

;;;; functions to encapsulate the REST server for Clojure

(defun xdmp-maybe-add-current-database (server)
  (if (plist-member server :database)
      server
    (append server (list :database (xdmp-get-current-database)))))

(defun xdmp-rest-connection->clj ()
  (oook-plist-to-map (xdmp-maybe-add-current-database oook-connection)))

;;;; functions to select databases

(defvar xdmp-database-history nil)

(defun xdmp-select-database (content-base)
  ;; also shows all databases because of the completion feature
  (interactive (list (completing-read (format "DB (default %s): " (xdmp-get-default-database)) (xdmp-get-databases) nil t nil 'xdmp-database-history (xdmp-get-default-database))))
  (setq oook-connection (plist-put oook-connection :content-base content-base)))

(defun xdmp-select-default-database ()
  (interactive)
  (xdmp-select-database (xdmp-get-default-database)))

(defun xdmp-select-modules-database ()
  (interactive)
  (xdmp-select-database (xdmp-get-modules-database)))

(defun xdmp-show-current-database ()
  (interactive)
  (message (xdmp-get-current-database)))


;;;; helper function to temporarily switch to the modules databse

(defvar xdmp-previous-database-stack nil)

(defun xdmp-switch-to-database (database)
  (push (xdmp-get-current-database) xdmp-previous-database-stack)
  (xdmp-select-database database))

(defun xdmp-switch-to-modules-database ()
  (xdmp-switch-to-database (xdmp-get-modules-database)))

(defun xdmp-maybe-switch-to-previous-database ()
  (let ((prev (pop xdmp-previous-database-stack)))
    (when prev
      (xdmp-select-database prev))))

(defmacro xdmp-with-database (database &rest body)
  `(prog2
       (xdmp-switch-to-database ,database)
       (progn ,@body)
     (xdmp-maybe-switch-to-previous-database)))

(defmacro xdmp-with-modules-database (&rest body)
  `(xdmp-with-database (xdmp-get-modules-database)
     ,@body))


;;;; main query function that wraps oook-eval

(defun xdmp-query (string &rest args)
  "Eval an xquery -- temporarily switches to modules-database when called with C-u"
  (interactive "sQuery: ")
  (let ((filename (plist-get args :filename))
        (args (plist-put args :eval-in-buffer `(progn
                                                 (xdmp-set-buffer-database ,(xdmp-get-current-database))
                                                 ,(plist-get args :eval-in-buffer)))))
    (if filename
        (apply 'oook-eval string #'oook-eval-to-file-handler nil args)
      (apply 'oook-eval string oook-eval-handler nil args))))

;;; document load / delete / list / show

(defvar xdmp-document-history (list "/"))
;; idea: maybe use a separate history when temporarily switched to modules database (20160921 mgr)

(defun xdmp-document-load/xdmp-document-load (&optional directory)
  "load document using xdmp:document-load via xquery

pro:
 - does work with binary files as well
con:
 - loads the file from the file system, ignores changes in the buffer that are not stored yet
 - needs file on the file system of the MarkLogic server
   - so it works only when you have MarkLogic on the same host as Emacs (usually, your localhost)"
  (interactive
   (list
    (let ((default (or xdmp-buffer-path (car xdmp-document-history))))
      (read-string (format "Directory [%s]: " (or default "")) nil
                   'xdmp-document-history
                   default))))
  (xdmp-with-database (xdmp-get-buffer-or-current-database)
   (let* ((local-uri (buffer-file-name))
          (filename (file-name-nondirectory (buffer-file-name)))
          (directory (if (not (string-equal "" directory))
                         (file-name-as-directory directory)
                       ""))
          (server-uri (concat directory filename)))
     (prog1
         (xdmp-query (format "
xquery version \"1.0-ml\";
xdmp:document-load(\"%s\",
                   <options xmlns=\"xdmp:document-load\">
                     <uri>%s</uri>
                     <repair>none</repair>
                     <permissions>{xdmp:default-permissions()}</permissions>
                   </options>)"
                             local-uri
                             server-uri))
       (xdmp-set-buffer-database (xdmp-get-current-database))
       (xdmp-set-buffer-path directory)))))

(defun xdmp-document-load/uruk-insert-string (&optional directory)
  "load document using new uruk.core/insert-string method of Uruk 0.3.7

pro:
 - also works if MarkLogic is installed on another host then the one where your Emacs runs
 - just uploads the current contents of the buffer even if it is has not been stored to disk yet
 - works for XML, JSON, and text files
con:
 - does not work for binary files
 - needs recent Uruk"
  (interactive
   (list
    (let ((default (or xdmp-buffer-path (car xdmp-document-history))))
      (read-string (format "Directory [%s]: " (or default "")) nil
                   'xdmp-document-history
                   default))))
  (xdmp-with-database (xdmp-get-buffer-or-current-database)
   (prog1
       (let* ((filename (file-name-nondirectory (or (buffer-file-name) (buffer-name))))
              (directory (if (not (string-equal "" directory))
                             (file-name-as-directory directory)
                           ""))
              (server-uri (concat directory filename))
              (eval-form (format "(let [host \"%s\"
                                        port %s
                                        db %s]
                                    (with-open [session (uruk.core/create-default-session (uruk.core/make-hosted-content-source host port db))]
                                      (doall (map str (uruk.core/insert-string session \"%%s\" \"%%s\")))))"
                                 (plist-get oook-connection :host)
                                 (plist-get oook-connection :port)
                                 (oook-plist-to-map oook-connection)))
              (form (format eval-form
                            server-uri
                            (replace-regexp-in-string "\"" "\\\\\""
                                                      (replace-regexp-in-string "\\\\" "\\\\\\\\" (buffer-string)))))
              (ns "uruk.core"))
         (cider-eval-form form ns)))
   (xdmp-set-buffer-database (xdmp-get-current-database))
   (xdmp-set-buffer-path directory)))

;; (fset 'xdmp-document-load (symbol-function 'xdmp-document-load/xdmp-document-load))
(fset 'xdmp-document-load (symbol-function 'xdmp-document-load/uruk-insert-string))

(defun xdmp-document-delete (&optional directory)
  (interactive
   (list
    (let ((default (or xdmp-buffer-path (car xdmp-document-history))))
      (read-string (format "Directory [%s]: " (or default ""))
                   nil
                   'xdmp-document-history
                   default))))
  (xdmp-with-database (xdmp-get-buffer-or-current-database)
   (let* ((local-uri (buffer-file-name))
          (filename (file-name-nondirectory (buffer-file-name)))
          (directory (if (not (string-equal "" directory))
                         (file-name-as-directory directory)
                       ""))
          (server-uri (concat directory filename)))
     (xdmp-query (format "
xquery version \"1.0-ml\";
xdmp:document-delete(\"%s\")"
                         server-uri)))))

(defvar xdmp-page-limit 1000)
(defun xdmp-set-page-limit (number)
  (interactive "NNew page limit: ")
  (setq xdmp-page-limit number))

(defvar xdmp-buffer-database
  nil
  "variable to hold the buffer's xdmp-database")

(defvar xdmp-buffer-path
  nil
  "variable to hold the buffer's oook list path")

(defun xdmp-get-buffer-or-current-database ()
  (interactive)
  (or xdmp-buffer-database
      (xdmp-get-current-database)))

(defun xdmp-set-buffer-database (database)
  ;; also shows all databases because of the completion feature
  (interactive (list (completing-read (format "DB (default %s): " (xdmp-get-buffer-or-current-database)) (xdmp-get-databases) nil t nil 'xdmp-database-history (xdmp-get-buffer-or-current-database))))
  (make-local-variable 'xdmp-buffer-database)
  (setq xdmp-buffer-database database))

(defun xdmp-set-buffer-path (path)
  ;; also shows all databases because of the completion feature
  (interactive
   (list
    (let ((default (or xdmp-buffer-path (car xdmp-document-history))))
      (read-string (format "Directory [%s]: " (or default "")) nil
                   'xdmp-document-history
                   default))))
  (make-local-variable 'xdmp-buffer-path)
  (setq xdmp-buffer-path path))

(defun xdmp-list-documents (&optional directory)
  "List documents (For paged output, set page limit with xdmp-set-page-limit.)
Use numerical prefix to switch to a different page.
(Cannot list documents with an URL not beginning with a '/'.)"
  (interactive
   (list
    (let ((default (or xdmp-buffer-path (car xdmp-document-history))))
     (read-string (format "Directory [%s]: " (or default ""))
                  nil
                  'xdmp-document-history
                  default))))
  (let ((page (prefix-numeric-value current-prefix-arg))
        (limit (or xdmp-page-limit 0)))
    (xdmp-query (format "
xquery version \"1.0-ml\";
let $results := xdmp:directory(\"%s\",\"infinity\")
let $count := count($results)
let $limit := %s
let $page := %s
let $offset := 1 + ($page - 1) * $limit
let $pageEnd := min(($offset + $limit - 1,$count))
let $database := xdmp:database-name(xdmp:database())
let $message :=
  if ($limit) then
    (let $numpages := ceiling($count div $limit)
      return concat('Displaying results ', $offset, ' - ', $pageEnd, ' of ', $count, ' (Page ', $page, ' of ', $numpages, ')'))
  else
    concat('Displaying all ', $count, ' results')
let $message := concat ($message, ' from DB: ', $database, ', path: %s')
return (
  $message
  ,
  fn:string-join( (for $d in (if ($limit) then subsequence($results,$offset,$limit) else $results)
                     return xdmp:node-uri($d)), '
'))
"
                        (file-name-as-directory directory)
                        limit
                        page
                        (file-name-as-directory directory))
  :buffer-name (format "*Oook List: %s (%s)*"
                       directory (xdmp-get-current-database))
  :eval-in-buffer `(progn
                    (xdmp-set-buffer-path ,directory)
                    (oook-list-mode)))))

(defun xdmp-show (&optional uri)
  (interactive
   (list
    (read-string (format "URI [%s]: " (or (car xdmp-document-history) ""))
                 nil
                 'xdmp-document-history
                 (car xdmp-document-history))))
  (let ((directory (file-name-directory uri))
        (filename (file-name-nondirectory uri)))
    ;; TODO(m-g-r): this is unnecessary with new `oook-to-file' approach.
    ;;(setq oook-buffer-filename fs-uri)
    (xdmp-with-database (xdmp-get-buffer-or-current-database)
     (xdmp-query (format "
xquery version \"1.0-ml\";
doc(\"%s\")"
                        uri)
                 :filename filename
                 :eval-in-buffer `(xdmp-set-buffer-path ,directory)))))

(defun xdmp-show-this ()
  (interactive)
  (let ((uri (whitespace-delimited-thing-at-point)))
    (xdmp-show uri)))

(defun xdmp-delete-this ()
  (interactive)
  (let ((uri (whitespace-delimited-thing-at-point)))
    (xdmp-document-delete uri)))

;; (global-set-key (kbd "C-c C-u") 'xdmp-document-load)
;; (global-set-key (kbd "C-c C-d") 'xdmp-document-delete)
;; (global-set-key (kbd "C-c C-q") 'xdmp-list-documents)

(provide 'xdmp-methods)
