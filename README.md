# Oook selector

This is the beginning of convenience tools for interacting with MarkLogic.

> Oook -- is all the [Librarian](https://en.wikipedia.org/wiki/Unseen_University#Librarian)
> at the university of the Discworld ever utters. He is the sole staff
> member of the greatest database of knowledge, and as such offers a
> very versatile and helpful interface to it.

### Warning

It is not even alpha but just some very early work and might change a lot.

### Successor of XDBC selector

The Oook selector replaces XDBC selector. Oook selector now
uses [Oook](https://github.com/xquery-mode/Oook) instead of Cider Any;
we decided to get rid of the backend design of cider-any and have a
simpler interface that just lets you evaluate XQuery documents.

## Installation

Please refer to the separate [installation instructions for Oook selector](INSTALL.md).

If you haven't installed MarkLogic and just want to test Oook selector,
you might want to follow our
[quick instructions to install MarkLogic Server](INSTALL-MarkLogic.md).


## Set up a Leiningen project

In order to use Oook selector, you have to start Cider REPL in a
Leiningen project. The [Uruk](https://github.com/daveliepmann/uruk)
library must be pinned in the `project.clj` in the dependencies section,
as Oook and Oook selector actually use Uruk to talk to MarkLogic via
[MarkLogic's XML Content Connector for Java (XCC/J)](https://docs.marklogic.com/javadoc/xcc/index.html).

If you don't program in Clojure but want to use the Oook selector
to access your XML database, you can just use a stub gateway project.
Just extract `uruk-gw.tbz`:
```
cd ~/src
tar xvfj oook-selector/uruk-gw.tbz 
```
or recreate the stub project yourself by executing:
```
cd ~/src

lein new app uruk-gw

cat > uruk-gw/project.clj <<__EOL__
(defproject uruk-gw "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :license {:name "Eclipse Public License"
            :url "http://www.eclipse.org/legal/epl-v10.html"}
  :dependencies [[org.clojure/clojure "1.8.0"]
                 [uruk "0.3.3"]]
  :main ^:skip-aot uruk-gw.core
  :target-path "target/%s"
  :profiles {:uberjar {:aot :all}})
__EOL__
```

## Usage

To use Oook selector, you cider-jack-in to an Uruk project by opening
the `uruk-gw/project.clj` file in Emacs and starting a Cider REPL by
entering `C-c m j`.

You actually use Oook selector by invoking `C-c m` plus an additional
letter. There is help available by pressing `?`.  With `C-c m x`, for
example, you can just evaluate an XQuery from a minibuffer.

All other commands have usually a lowercase version for the current database, and
a UPPERCASE one for the modules database of the current session/connection.

### Complete list of available selector methods:

- general methods:
  - `C-c m ?` - Selector help buffer
  - `C-c m q` - Quit / abort
- Cider convenience functions:
  - `C-c m j` - (cider) Start an nREPL server for the current project and connect to it.
  - `C-c m r` - (cider) Select the REPL buffer, when possible in an existing window.
  - `C-c m R` - (cider) Switch to the last Clojure buffer.
- simple XQuery evaluation:
  - `C-c m x` - Evaluate an XQuery from minibuffer
  - `C-c m X` - Evaluate an XQuery from minibuffer in the modules database
- document management:
  - `C-c m l` - List documents †
  - `C-c m L` - List documents in the modules database †
  - `C-c m s` - Show document ‡
  - `C-c m S` - Show document in the modules database ‡
  - `C-c m t` - Show this document at point ‡
  - `C-c m T` - Show this document at point in the modules database ‡
  - `C-c m u` - Upload document ‡
  - `C-c m U` - Upload document into the modules database ‡
  - `C-c m d` - Delete document ‡
  - `C-c m D` - Delete document in the modules database
  - `C-c m b` - Set server path for current buffer ‡
  - `C-c m B` - Set database for current buffer ‡
- database selection:
  - `C-c m c` - Choose/select database within current session/connection
  - `C-c m .` - Select default database of the server
  - `C-c m ,` - Select modules database of the server
  - `C-c m -` - Show which database is currently used
  - `C-c m /` - Show which database is currently used

#### † Notes on the Document list
* Press  `u`  to update the document list
* Press  `<Return>`  on a document's URI to show the document at point
  (This is the same as entering  `C-c m t`  outside of a Document list.)
* For paged output, set page limit with xdmp-set-page-limit.
  Use numerical prefix to switch to a different page.
* Currently, it cannot list documents with an URL not beginning with a `/`.

#### ‡ Notes server path and database of the current buffer

When a file is directly opened from MarkLogic using `Show document`
(and friends) or uploaded at a new location, its server path and
database are stored in buffer local variables.

"Upload document" and "Delete document" obey these variables, so that
you can just update the document in MarkLogic or delete it from the
database by entering `C-c m u` and `C-c m d`, respectively, from
within the opened file buffer.

You can set those variables explicitly by entering  `C-c m b` (set
server path) and `C-c m B` (set database). To upload to a new path,
you can also just enter a different path than the suggested when
uploading by entering  `C-c m u`.

#### Note on upload and delete document methods

To use upload and delete document you should have the file that is to
be transfered or delete open in a buffer. If you fire the command the
filename will be taken from the buffer and you will be interactively
queried to enter a directory path.  The file will be uploaded with a
URI of `<directory>/<filename>`.  Delete works analogously.
