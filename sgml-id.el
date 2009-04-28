;;; sgml-id.el --- set of functions for finding cross-referenced IDs

;; Copyright (C) 2003 Florian v. Savigny
;; Copyright (C) 1992 Free Software Foundation, Inc.

;; Author: Florian v. Savigny <lorian@fsavigny.de>
;;      James Clark <jjc@clark.com>
;; Maintainer: Florian v. Savigny <lorian@fsavigny.de>
;; Keywords: languages

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary:

;; Set of three user functions to comfortably find elements with
;; certain IDs. It was of course conceived while using psgml-mode, but
;; does not require it to work. Principally, it should work from any
;; buffer visiting an SGML file, no matter what the mode. It does
;; require James Clark's nsgmls, though.

;; Send bugs to <lorian@fsavigny.de>.
;; Any other feedback is also welcome.

;; WHAT IT CAN DO

;; sgml-id provides three user functions:

;; sgml-id-display-element-with-id-under-cursor is meant for the
;; situation when you see a reference to an ID and you ask yourself
;; "Now what element was that?". Put the cursor on the ID reference
;; and invoke the function (I have bound it to C-c f). Other windows
;; will be deleted, the remaining window split in two and the element
;; you've been looking for will be displayed in the upper window.

;; sgml-id-display-list (bound to C-c i) displays a complete list of
;; all IDs used in the current SGML instance (in case you have
;; forgotten an ID name you would like to refer to), which is shown on
;; the left side in a kind of menu-bar window (as on web pages). The
;; first letter of the element is also shown in parentheses, as a
;; reminder. This buffer is put in sgml-id-mode, which is nothing
;; more than View Mode with one additional function:

;; sgml-id-display-element-other-window (bound to f in sgml-id-mode)
;; is used from the "ID menu bar" on the left side. It does the same
;; thing as sgml-id-display-element-with-id-under-cursor, but takes
;; the ID from the LINE the cursor is on in the "ID menu bar", so the
;; cursor needn't necessarily be on the ID itself; and it first jumps
;; to the main window, deleting the "ID menu bar". As a special
;; gimmick, the ID in question is put in front of the kill ring, in
;; case you want to paste it.
;;
;; See also under LIMITATIONS for some caveats.

;; INSTALLING

;; to test, visit an SGML file and load this file with load-file,
;; or vice versa

;; 0. Make sure nsgmls is installed on your system.

;; 1. put this file somewhere in your load-path
;;    (e.g. /usr/share/emacs/site-lisp/psgml)
;;
;; 2. have it loaded, e.g. via the sgml-mode-hook in your ~/.emacs:
;;
;;    (add-hook 'sgml-mode-hook
;;        '(lambda ()
;;           (load "sgml-id")))
;;
;; 3. if you want to modify the key bindings (e.g. in the same hook),
;;    do so AFTER having loaded this file (you may want to copy lines
;;    from the end of this file as templates). The default keybindings
;;    are for sgml-mode.
;;
;; 4. to change the key binding of
;;    sgml-id-display-element-other-window, you would have to use
;;    sgml-id-mode-hook (which I have not tried out yet).

;; LIMITATIONS, I.E. BUGS I DIDN'T LIKE TO FIX:

;; The whole thing is essentially beta, since it does work quite
;; elegantly and reliably, but has the following flaws:

;; - the only "classic" bug, which has remained mysterious to me: when
;; invoking C-c f for the first time (i.e. when sgml-id-alist is still
;; nil), the regex-search for the element with the id fails for
;; reasons obscure to me, since the regex is made correctly (as stated
;; in the error message). Solution: press C-c f a second time. I have
;; no idea why. [See sgml-id-display-element-with-id]

;; - it looks for IDs (and the attribute names that have these IDs as
;; their value) case-insensitively, which is usually appropriate for
;; SGML, but not for XML. This behaviour should be changeable and
;; depend on the kind of language. [See sgml-id-build-list]

;; - it only works for one SGML instance in one Emacs session, since I
;; have not been able to get those buffer-local variables to work. To
;; use it with a second instance in the same session, you must do two
;; things: first, kill the "ID menu-bar" buffer (which has the name
;; "IDs"), second, invoke sgml-id-display-list from the buffer
;; visiting the new SGML instance. Do this before using
;; sgml-id-display-element-with-id-under-cursor. [See
sgml-id-build-list]

;; - more seriously, updating (e.g., after having introduced a new ID)
;; is about the same: kill the "IDs" buffer, save the SGML file and
;; invoke sgml-id-display-list. Do this before using
;; sgml-id-display-element-with-id-under-cursor. This should ideally
;; be done automatically; ideally depending on the insertion of a new
;; attribute value of the type ID in the buffer (hyperideally with
;; checking whether such an insertion has been made since the list was
;; last built). [See sgml-id-display-element-with-id and
;; sgml-id-display-list, respectively]

;; - it only finds elements with IDs in the current buffer, not in
;; files included via an entity. This is irritating, since their IDs
;; are very much displayed in the ID list. It could be done via
;; storing the file name of IDs not in the current buffer, but this
;; would imply a different type of alist (and it would presumably slow
;; down the building of the list). [Changes would have to be made in
;; sgml-id-build-list, and in sgml-id-display-element-with-id]

;; Any fixes or useful suggestions for these problems are most welcome
;; and should be directed to <lorian@fsavigny.de>.

;;; Code:

;; initializing:

(setq sgml-id-alist '())
(setq sgml-id-buffer "") ; this is deliberately an empty string (see
                         ; sgml-id-display-list)

;; core functions:

;; the following function builds two "lists", one for the user to see
;; and one for internal use. Although the user functions usually need
;; only either of these, both are always built in one sweep.

(defun sgml-id-build-list ()
  "Make a list of used IDs and put it in buffer \"IDs\"; and make an
internal alist \"sgml-id-alist\" for lookup. If any of these is
already present, update it."
  (message "Building ID list ...")
  (setq sgml-id-alist '()) ; if present, empty it
  (setq sgml-id-buffer (buffer-name (get-buffer-create "IDs")))
  ; BUG: this variable should somehow be made buffer-local
  (let ((sgml-buffer (current-buffer))
        id
        att
        element)
    (save-excursion (set-buffer sgml-id-buffer)
                    (fundamental-mode)
                    (erase-buffer) ; in case we're updating
                    (insert "ID (Element)\n-- ---------\n\n")
                    (setq id-sgml-instance-buffer sgml-buffer))
                    ; BUG: this variable should also be buffer-local
    (call-process "nsgmls" nil "*ESIS*" nil "-oline"
                  "-oid" (buffer-file-name))
    (set-buffer "*ESIS*")
    (goto-char (point-min))
    (while
        (search-forward-regexp "^A\\([^ ]+\\) ID \\([^ \n]+\\)" nil t)
      (setq id (downcase (match-string 2))
            att (downcase (match-string 1)))
      ; BUG: these downcases should not be there when used with XML
      (search-forward-regexp "^\(\\([^ \n]\\)" nil t)
      (setq element (downcase (match-string 1)))
      (setq sgml-id-alist (cons (cons id att) sgml-id-alist))
      (save-excursion
        (set-buffer sgml-id-buffer)
        (insert (concat id " (" element ")\n")))))
  (kill-buffer "*ESIS*")
  (save-excursion
    (set-buffer sgml-id-buffer)
    (sgml-id-mode))
  (message " ... done."))

(defun sgml-display-element-with-id (id)
  "Display element in current buffer that has id ID in a new window."
  (delete-other-windows)
  (if (not sgml-id-alist)
      (sgml-id-build-list))
  ; BUG: checking whether updating is needed would be fine here
  (split-window-vertically)
  (goto-char (point-min))
  (re-search-forward (concat
                      (cdr (assoc id sgml-id-alist))
                      "=\"?"
                      id
                      "\"?"))
  ; BUG: here the search fails on the first invocation, but why?
  (other-window 1))

; user-functions, which always use at least one of the above

(defun sgml-id-display-element-with-id-under-cursor ()
  "Find element in current buffer with ID equal to the word under the
cursor. Display it in separate window."
  (interactive)
  (sgml-display-element-with-id (current-word)))

(defun sgml-id-display-list ()
  "Display list of used IDs, in a kind of \"menu bar\" window on the
left side."
  (interactive)
  (if (not (get-buffer sgml-id-buffer))
      (sgml-id-build-list))
  ; BUG: checking whether updating is needed would be fine here
  (delete-other-windows)
  (split-window-horizontally 24)
  (switch-to-buffer sgml-id-buffer))  ; that was set by
sgml-id-build-list

(define-derived-mode sgml-id-mode view-mode
  "ID" "Essentially view mode with an additional function for using a
list of IDs to search for them in an SGML/XML file in another
window. This mode need not be invoked manually (it is done by
sgml-id-display-list).\n\n\\{sgml-id-mode-map}"
  (define-key sgml-id-mode-map [?f]
    'sgml-id-display-element-other-window))

(defun sgml-id-display-element-other-window ()
  "Works like sgml-display-element-with-id-under-cursor, but is for
searches in the other (main) window (which is then split in two). Puts
ID in front of kill ring, for convenient pasting."
  (interactive)
  (beginning-of-line)
  (let ((id (current-word)))
    (kill-new id)
    (other-window 1)
    (sgml-display-element-with-id id)))

;; key bindings

(define-key sgml-mode-map "\C-cf"
  'sgml-id-display-element-with-id-under-cursor)
(define-key sgml-mode-map "\C-ci" 'sgml-id-display-list)
