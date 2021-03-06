;;; completion/ivy/autoload/ivy.el

;; Show more information in ivy-switch-buffer; and only display
;; workgroup-relevant buffers.
(defun +ivy--get-buffers (&optional buffer-list)
  (let ((min-name 5)
        (min-mode 5)
        (proot (doom-project-root)))
    (mapcar
     (lambda (b) (format (format "%%-%ds %%-%ds %%s" min-name min-mode)
                    (nth 0 b)
                    (nth 1 b)
                    (or (nth 2 b) "")))
     (mapcar (lambda (b)
               (with-current-buffer b
                 (let ((buffer-name (buffer-name b))
                       (mode-name (symbol-name major-mode)))
                   (when (> (length buffer-name) min-name)
                     (setq min-name (+ (length buffer-name) 15)))
                   (when (> (length mode-name) min-mode)
                     (setq min-mode (+ (length mode-name) 3)))
                   (list (concat
                          (propertize buffer-name
                                      'face (cond ((string-match-p "^ ?\\*" buffer-name)
                                                   'font-lock-comment-face)
                                                  ((not (string= proot (doom-project-root)))
                                                   'font-lock-keyword-face)
                                                  (buffer-read-only
                                                   'error)))
                          (when (and buffer-file-name (buffer-modified-p))
                            (propertize "[+]" 'face 'doom-modeline-buffer-modified)))
                         (propertize mode-name 'face 'font-lock-constant-face)
                         (when buffer-file-name
                           (abbreviate-file-name (file-name-directory buffer-file-name)))))))
             (or buffer-list (doom-buffer-list))))))

(defun +ivy--select-buffer-action (buffer)
  (ivy--switch-buffer-action
   (s-chop-suffix
    "[+]"
    (substring buffer 0 (string-match-p (regexp-quote "   ") buffer)))))

(defun +ivy--select-buffer-other-window-action (buffer)
  (ivy--switch-buffer-other-window-action
   (s-chop-suffix
    "[+]"
    (substring buffer 0 (string-match-p (regexp-quote "   ") buffer)))))

;;;###autoload
(defun +ivy/switch-workspace-buffer (&optional other-window-p)
  "Switch to an open buffer in the current workspace."
  (interactive "P")
  (+ivy/switch-buffer other-window-p t))

;;;###autoload
(defun +ivy/switch-buffer (&optional other-window-p workspace-only-p)
  "Switch to an open buffer in the global buffer list. If WORKSPACE-ONLY-P,
limit to buffers in the current workspace."
  (interactive "P")
  (ivy-read (format "%s buffers: " (if workspace-only-p "Workspace" "Global"))
            (+ivy--get-buffers (unless workspace-only-p (buffer-list)))
            :action (if other-window-p
                        '+ivy--select-buffer-other-window-action
                      '+ivy--select-buffer-action)
            :matcher 'ivy--switch-buffer-matcher
            :keymap ivy-switch-buffer-map
            :caller '+ivy/switch-workspace-buffer))

;; TODO refactor ivy task candidate functions (messy!)
(defun +ivy--tasks-candidates (tasks)
  "Generate a list of task tags (specified by `+ivy-task-tags') for
`+ivy/tasks'."
  (let* ((max-type-width (seq-max (mapcar #'length (mapcar #'car +ivy-task-tags))))
         (max-desc-width (seq-max (mapcar #'length (mapcar #'cl-cdadr tasks))))
         (max-width (max 25 (min (- (frame-width) (+ max-type-width 1))
                                 max-desc-width)))
         (fmt (format "%%-%ds %%-%ds%%s%%s:%%s" max-type-width max-desc-width))
         lines)
    (dolist (alist tasks (nreverse lines))
      (let-alist alist
        (push (format fmt
                      (propertize .type 'face (cdr (assoc .type +ivy-task-tags)))
                      (substring .desc 0 (min max-desc-width (length .desc)))
                      (propertize " | " 'face 'font-lock-comment-face)
                      (propertize (abbreviate-file-name .file) 'face 'font-lock-keyword-face)
                      (propertize .line 'face 'font-lock-constant-face))
              lines)))))

(defun +ivy--tasks (target)
  (let (case-fold-search)
    (delq
     nil
     (mapcar (lambda (x)
               (save-match-data
                 (when (string-match (concat "^\\([^:]+\\):\\([0-9]+\\):.+\\("
                                             (string-join (mapcar #'car +ivy-task-tags) "\\|")
                                             "\\):?\\s-*\\(.+\\)")
                                     x)
                   `((type . ,(match-string 3 x))
                     (desc . ,(match-string 4 x))
                     (file . ,(match-string 1 x))
                     (line . ,(match-string 2 x))))))
             (let ((command (or (let ((bin (executable-find "rg")))
                                  (and bin (concat bin " --line-number")))
                                (let ((bin (executable-find "ag")))
                                  (and bin (concat bin " --numbers")))
                                (error "Neither ripgrep or the_silver_searcher is available")))
                   (args (concat " -- "
                                 (shell-quote-argument
                                  (concat "\\s("
                                          (string-join (mapcar #'car +ivy-task-tags) "|")
                                          ")([\\s:]|\\([^)]+\\):?)")))))
               (when-let (out (shell-command-to-string
                               (format "%s -H -S --no-heading %s %s"
                                       command args target)))
                 (split-string out "\n" t)))))))

(defun +ivy--tasks-open-action (x)
  "Jump to the file and line of the current task."
  (let ((location (cadr (split-string x " | ")))
        (type (car (split-string x " "))))
    (destructuring-bind (file line) (split-string location ":")
      (with-ivy-window
        (find-file (expand-file-name file (doom-project-root)))
        (goto-char (point-min))
        (forward-line (1- (string-to-number line)))
        (search-forward type (line-end-position) t)
        (backward-char (length type))
        (recenter)))))

;;;###autoload
(defun +ivy/tasks (&optional arg)
  "Search through all TODO/FIXME tags in the current project. If ARG, only
search current file. See `+ivy-task-tags' to customize what this searches for."
  (interactive "P")
  (ivy-read (format "Tasks (%s): "
                    (if arg
                        (concat "in: " (file-relative-name buffer-file-name))
                      "project"))
            (+ivy--tasks-candidates
             (+ivy--tasks (if arg buffer-file-name (doom-project-root))))
            :action #'+ivy--tasks-open-action
            :caller '+ivy/tasks))

;;;###autoload
(defun +ivy*counsel-ag-function (string base-cmd extra-ag-args)
  "Advice to 1) get rid of the character limit from `counsel-ag-function' and 2)
disable ivy's over-zealous parentheses quoting behavior (if i want literal
parentheses, I'll escape them myself).

NOTE This may need to be updated frequently, to meet changes upstream (in
counsel-rg)."
  (when (null extra-ag-args)
    (setq extra-ag-args ""))
  (if (< (length string) 1)  ;; #1
      (counsel-more-chars 1)
    (let ((default-directory counsel--git-grep-dir)
          (regex (counsel-unquote-regex-parens
                  (setq ivy--old-re
                        (ivy--regex
                         (counsel-unquote-regex-parens string)))))) ;; #2
      (let* ((args-end (string-match " -- " extra-ag-args))
             (file (if args-end
                       (substring-no-properties extra-ag-args (+ args-end 3))
                     ""))
             (extra-ag-args (if args-end
                                (substring-no-properties extra-ag-args 0 args-end)
                              extra-ag-args))
             (ag-cmd (format base-cmd
                             (concat extra-ag-args
                                     " -- "
                                     (shell-quote-argument regex)
                                     file))))
        (if (file-remote-p default-directory)
            (split-string (shell-command-to-string ag-cmd) "\n" t)
          (counsel--async-command ag-cmd)
          nil)))))

;;;###autoload
(defun +ivy/wgrep-occur ()
  "Invoke the search+replace wgrep buffer on the current ag/rg search results."
  (interactive)
  (if (not (window-minibuffer-p))
      (user-error "No completion session is active")
    (require 'wgrep)
    (let* ((caller (ivy-state-caller ivy-last))
           (occur-fn (plist-get ivy--occurs-list caller))
           (buffer
            (generate-new-buffer
             (format "*ivy-occur%s \"%s\"*"
                     (if caller (concat " " (prin1-to-string caller)) "")
                     ivy-text))))
      (with-current-buffer buffer
        (let ((inhibit-read-only t))
          (erase-buffer)
          (funcall occur-fn))
        (setf (ivy-state-text ivy-last) ivy-text)
        (setq ivy-occur-last ivy-last)
        (setq-local ivy--directory ivy--directory))
      (ivy-exit-with-action
       `(lambda (_)
          (pop-to-buffer ,buffer)
          (ivy-wgrep-change-to-wgrep-mode))))))

;;;###autoload
(defun +ivy-yas-prompt (prompt choices &optional display-fn)
  (yas-completing-prompt prompt choices display-fn #'ivy-completing-read))

;;;###autoload
(defun +ivy-git-grep-other-window-action (x)
  "Opens the current candidate in another window."
  (when (string-match "\\`\\(.*?\\):\\([0-9]+\\):\\(.*\\)\\'" x)
    (select-window
     (with-ivy-window
       (let ((file-name   (match-string-no-properties 1 x))
             (line-number (match-string-no-properties 2 x)))
         (find-file-other-window (expand-file-name file-name counsel--git-grep-dir))
         (goto-char (point-min))
         (forward-line (1- (string-to-number line-number)))
         (re-search-forward (ivy--regex ivy-text t) (line-end-position) t)
         (run-hooks 'counsel-grep-post-action-hook)
         (selected-window))))))

;;;###autoload
(defun +ivy-quit-and-resume ()
  "Close the current popup window and resume ivy."
  (interactive)
  (when (doom-popup-p)
    (doom/popup-close))
  (ivy-resume))

;;;###autoload
(defun +ivy/backward-kill-word ()
  "Kill a word backwards, but only if cursor is after `minibuffer-prompt-end',
to prevent the 'Text is read-only' warning from monopolizing the minibuffer."
  (interactive)
  (call-interactively
   (if (> (point) (minibuffer-prompt-end))
       #'backward-kill-word
     #'ivy-backward-delete-char)))
