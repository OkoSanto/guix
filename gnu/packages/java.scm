;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2015, 2016, 2017 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2016 Leo Famulari <leo@famulari.name>
;;; Copyright © 2016, 2017 Roel Janssen <roel@gnu.org>
;;; Copyright © 2017 Carlo Zancanaro <carlo@zancanaro.id.au>
;;; Copyright © 2017 Julien Lepiller <julien@lepiller.eu>
;;; Copyright © 2017 Thomas Danckaert <post@thomasdanckaert.be>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages java)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix hg-download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system ant)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages)
  #:use-module (gnu packages attr)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages cpio)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gawk)
  #:use-module (gnu packages gettext)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages gnuzilla) ;nss
  #:use-module (gnu packages ghostscript) ;lcms
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages icu4c)
  #:use-module (gnu packages image)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages linux) ;alsa
  #:use-module (gnu packages wget)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages popt)
  #:use-module (gnu packages kerberos)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages texinfo)
  #:use-module ((srfi srfi-1) #:select (fold alist-delete))
  #:use-module (srfi srfi-11)
  #:use-module (ice-9 match))


;;;
;;; Java bootstrap toolchain.
;;;

;; The Java bootstrap begins with Jikes, a Java compiler written in C++.  We
;; use it to build the SableVM standard library and virtual machine, which are
;; written in a simpler dialect of Java and C, respectively.  This is
;; sufficient to build an older version of Ant, which is needed to build an
;; older version of ECJ, an incremental Java compiler, both of which are
;; written in Java.
;;
;; ECJ is needed to build the latest release of GNU Classpath (0.99).
;; Classpath (> 0.98) is a requirement for JamVM, a more modern implementation
;; of the Java virtual machine.
;;
;; With JamVM we can build the latest development version of GNU Classpath,
;; which has much more support for Java 1.6 than the latest release.  Since
;; the previous build of JamVM is limited by the use of GNU Classpath 0.99 we
;; rebuild it with the latest development version of GNU Classpath.
;;
;; Finally, we use the bootstrap toolchain to build the OpenJDK with the
;; Icedtea 1.x build framework.  We then build the more recent JDKs Icedtea
;; 2.x and Icedtea 3.x.

(define jikes
  (package
    (name "jikes")
    (version "1.22")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/jikes/Jikes/"
                                  version "/jikes-" version ".tar.bz2"))
              (sha256
               (base32
                "1qqldrp74pzpy5ly421srqn30qppmm9cvjiqdngk8hf47dv2rc0c"))))
    (build-system gnu-build-system)
    (home-page "http://jikes.sourceforge.net/")
    (synopsis "Compiler for the Java language")
    (description "Jikes is a compiler that translates Java source files as
defined in The Java Language Specification into the bytecoded instruction set
and binary format defined in The Java Virtual Machine Specification.")
    (license license:ibmpl1.0)))

(define sablevm-classpath
  (package
    (name "sablevm-classpath")
    (version "1.13")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/sablevm/sablevm/"
                                  version "/sablevm-classpath-" version ".tar.gz"))
              (sha256
               (base32
                "1qyhyfz8idghxdam16hdgpa24r2x4xbg9z8c8asa3chnd79h3zw2"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags
       (list "--with-jikes"
             "--disable-Werror"
             "--disable-gmp"
             "--disable-gtk-peer"
             "--disable-plugin"
             "--disable-dssi"
             "--disable-alsa"
             "--disable-gjdoc")))
    (inputs
     `(("gconf" ,gconf)
       ("gtk+" ,gtk+-2)))
    (native-inputs
     `(("jikes" ,jikes)
       ("fastjar" ,fastjar)
       ("pkg-config" ,pkg-config)))
    (home-page "http://sablevm.org/")
    (synopsis "Java Virtual Machine")
    (description "SableVM is a clean-room, highly portable and efficient Java
virtual machine.  Its goals are to be reasonably small, fast, and compliant
with the various specifications (JVM specification, JNI, invocation interface,
etc.).  SableVM is no longer maintained.

This package provides the classpath library.")
    (license license:lgpl2.1+)))

(define sablevm
  (package
    (name "sablevm")
    (version "1.13")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/sablevm/sablevm/"
                                  version "/sablevm-" version ".tar.gz"))
              (sha256
               (base32
                "1jyg4bsym6igz94wps5443c7wiwlzinqzkchcw972nz4kf1cql6g"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags
       (list "--with-internal-libffi=no"
             "--with-internal-libpopt=no")
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'remove-timestamp-for-reproducibility
           (lambda _
             (substitute* "src/sablevm/Makefile.in"
               (("\\$\\(SVMCOMPILETIME\\)") "(unknown)"))
             #t))
         (add-after 'unpack 'link-with-popt
           (lambda _
             (substitute* "src/sablevm/Makefile.in"
               (("\\$\\(SVMADD\\)" match)
                (string-append match " -lpopt")))
             #t))
         (add-after 'unpack 'patch-path-to-classpath
           (lambda* (#:key inputs #:allow-other-keys)
             (substitute* "Makefile.in"
               (("@datadir@/sablevm-classpath")
                (string-append (assoc-ref inputs "classpath")
                               "/share/sablevm-classpath")))
             (substitute* "src/libsablevm/Makefile.in"
               (("\\$\\(libdir\\)/sablevm-classpath")
                (string-append (assoc-ref inputs "classpath")
                               "/lib/sablevm-classpath"))
               (("\\$\\(datadir\\)/sablevm-classpath")
                (string-append (assoc-ref inputs "classpath")
                               "/share/sablevm-classpath")))
             #t)))))
    (inputs
     `(("classpath" ,sablevm-classpath)
       ("jikes" ,jikes)
       ("zlib" ,zlib)
       ("popt" ,popt)
       ("libffi" ,libffi)))
    (native-inputs
     `(("libltdl" ,libltdl)))
    (home-page "http://sablevm.org/")
    (synopsis "Java Virtual Machine")
    (description "SableVM is a clean-room, highly portable and efficient Java
virtual machine.  Its goals are to be reasonably small, fast, and compliant
with the various specifications (JVM specification, JNI, invocation interface,
etc.).  SableVM is no longer maintained.

This package provides the virtual machine.")
    (license license:lgpl2.1+)))

(define ant-bootstrap
  (package
    (name "ant-bootstrap")
    ;; The 1.10.x series requires Java 8.  1.9.0 and later use generics, which
    ;; are not supported.  The 1.8.x series is the last to use only features
    ;; supported by Jikes, but it cannot seem to be built with sablevm.
    (version "1.7.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://archive.apache.org/dist/"
                                  "ant/source/apache-ant-"
                                  version "-src.tar.bz2"))
              (sha256
               (base32
                "19pvqvgkxgpgsqm4lvbki5sm0z84kxmykdqicvfad47gc1r9mi2d"))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f ; no "check" target
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda* (#:key inputs #:allow-other-keys)
             (setenv "JAVA_HOME"
                     (string-append (assoc-ref inputs "sablevm")
                                    "/lib/sablevm"))
             (setenv "JAVACMD"
                     (string-append (assoc-ref inputs "sablevm")
                                    "/bin/java-sablevm"))
             (setenv "JAVAC"
                     (string-append (assoc-ref inputs "sablevm")
                                    "/bin/javac-sablevm"))

             ;; Use jikes instead of javac for <javac ...> tags in build.xml
             (setenv "ANT_OPTS" "-Dbuild.compiler=jikes")

             ;; jikes produces lots of warnings, but they are not very
             ;; interesting, so we silence them.
             (setenv "$BOOTJAVAC_OPTS" "-nowarn")

             ;; Disable tests because we are bootstrapping and thus don't have
             ;; any of the dependencies required to build and run the tests.
             (substitute* "build.xml"
               (("depends=\"jars,test-jar\"") "depends=\"jars\""))
             (zero? (system* "bash" "bootstrap.sh"
                             (string-append "-Ddist.dir="
                                            (assoc-ref %outputs "out"))))))
         (delete 'install))))
    (native-inputs
     `(("jikes" ,jikes)
       ("sablevm" ,sablevm)))
    (home-page "http://ant.apache.org")
    (synopsis "Build tool for Java")
    (description
     "Ant is a platform-independent build tool for Java.  It is similar to
make but is implemented using the Java language, requires the Java platform,
and is best suited to building Java projects.  Ant uses XML to describe the
build process and its dependencies, whereas Make uses Makefile format.")
    (license license:asl2.0)))

;; Version 3.2.2 is the last version without a dependency on a full-fledged
;; compiler for Java 1.5.
(define ecj-bootstrap
  (package
    (name "ecj-bootstrap")
    (version "3.2.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://archive.eclipse.org/eclipse/"
                                  "downloads/drops/R-" version
                                  "-200702121330/ecjsrc.zip"))
              (sha256
               (base32
                "05hj82kxd23qaglsjkaqcj944riisjha7acf7h3ljhrjyljx8307"))))
    ;; It would be so much easier if we could use the ant-build-system, but we
    ;; cannot as we don't have ant at this point.  We use ecj for
    ;; bootstrapping the JDK.
    (build-system gnu-build-system)
    (arguments
     `(#:modules ((guix build gnu-build-system)
                  (guix build utils)
                  (srfi srfi-1))
       #:tests? #f ; there are no tests
       #:phases
       (modify-phases %standard-phases
         (replace 'configure
           (lambda* (#:key inputs #:allow-other-keys)
             (setenv "CLASSPATH"
                     (string-join
                      (find-files (string-append (assoc-ref inputs "ant-bootstrap")
                                                 "/lib")
                                  "\\.jar$")
                      ":"))
             #t))
         (replace 'build
           (lambda* (#:key inputs #:allow-other-keys)
             ;; The unpack phase enters the "org" directory by mistake.
             (chdir "..")

             ;; Create a simple manifest to make ecj executable.
             (with-output-to-file "manifest"
               (lambda _
                 (display "Manifest-Version: 1.0
Main-Class: org.eclipse.jdt.internal.compiler.batch.Main\n")))

             ;; Compile it all!
             (and (zero? (apply system* "javac-sablevm"
                                (find-files "." "\\.java$")))
                  (zero? (system* "fastjar" "cvfm"
                                  "ecj-bootstrap.jar" "manifest" ".")))))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((share (string-append (assoc-ref outputs "out")
                                         "/share/java/")))
               (mkdir-p share)
               (install-file "ecj-bootstrap.jar" share)
               #t))))))
    (native-inputs
     `(("ant-bootstrap" ,ant-bootstrap)
       ("unzip" ,unzip)
       ("sablevm" ,sablevm)
       ("fastjar" ,fastjar)))
    (home-page "https://eclipse.org")
    (synopsis "Eclipse Java development tools core batch compiler")
    (description "This package provides the Eclipse Java core batch compiler
for bootstrapping purposes.  The @dfn{Eclipse compiler for Java} (ecj) is a
requirement for all GNU Classpath releases after version 0.93.")
    (license license:epl1.0)))

(define ecj-javac-wrapper
  (package (inherit ecj-bootstrap)
    (name "ecj-javac-wrapper")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (let ((backend 'sablevm))
         (use-modules (guix build utils))
         (let* ((bin    (string-append (assoc-ref %outputs "out") "/bin"))
                (target (string-append bin "/javac"))
                (guile  (string-append (assoc-ref %build-inputs "guile")
                                       "/bin/guile"))
                (ecj    (string-append (assoc-ref %build-inputs "ecj-bootstrap")
                                       "/share/java/ecj-bootstrap.jar"))
                (java   (case backend
                          ((sablevm)
                           (string-append (assoc-ref %build-inputs "sablevm")
                                          "/lib/sablevm/bin/java"))
                          ((jamvm)
                           (string-append (assoc-ref %build-inputs "jamvm")
                                          "/bin/jamvm"))))
                (bootcp (case backend
                          ((sablevm)
                           (let ((jvmlib (string-append
                                          (assoc-ref %build-inputs "sablevm-classpath")
                                          "/lib/sablevm")))
                             (string-append jvmlib "/jre/lib/rt.jar")))
                          ((jamvm)
                           (let ((jvmlib (string-append (assoc-ref %build-inputs "classpath")
                                                        "/share/classpath")))
                             (string-append jvmlib "/lib/glibj.zip:"
                                            jvmlib "/lib/tools.zip"))))))
           (mkdir-p bin)
           (with-output-to-file target
             (lambda _
               (format #t "#!~a --no-auto-compile\n!#\n" guile)
               (write
                `(begin (use-modules (ice-9 match)
                                     (ice-9 receive)
                                     (ice-9 hash-table)
                                     (srfi srfi-1)
                                     (srfi srfi-26))
                        (define defaults
                          '(("-bootclasspath" ,bootcp)
                            ("-source" "1.5")
                            ("-target" "1.5")
                            ("-cp"     ".")))
                        (define (main args)
                          (let ((classpath (getenv "CLASSPATH")))
                            (setenv "CLASSPATH"
                                    (string-append ,ecj
                                                   (if classpath
                                                       (string-append ":" classpath)
                                                       ""))))
                          (receive (vm-args other-args)
                              ;; Separate VM arguments from arguments to ECJ.
                              (partition (cut string-prefix? "-J" <>)
                                         (fold (lambda (default acc)
                                                 (if (member (first default) acc)
                                                     acc (append default acc)))
                                               args defaults))
                            (apply system* ,java
                                   (append
                                    ;; Remove "-J" prefix
                                    (map (cut string-drop <> 2) vm-args)
                                    '("org.eclipse.jdt.internal.compiler.batch.Main")
                                    (cons "-nowarn" other-args)))))
                        ;; Entry point
                        (let ((args (cdr (command-line))))
                          (if (null? args)
                              (format (current-error-port) "javac: no arguments given!\n")
                              (main args)))))))
           (chmod target #o755)
           #t))))
    (native-inputs
     `(("guile" ,guile-2.2)
       ("ecj-bootstrap" ,ecj-bootstrap)
       ("sablevm" ,sablevm)
       ("sablevm-classpath" ,sablevm-classpath)))
    (description "This package provides a wrapper around the @dfn{Eclipse
compiler for Java} (ecj) with a command line interface that is compatible with
the standard javac executable.")))

;; Note: All the tool wrappers (e.g. for javah, javac, etc) fail with
;; java.lang.UnsupportedClassVersionError.  They simply won't run on the old
;; sablevm.  We use Classpath 0.99 to build JamVM, on which the Classpath
;; tools do run.  Using these Classpath tools on JamVM we can then build the
;; development version of GNU Classpath.
(define classpath-on-sablevm
  (package
    (name "classpath")
    (version "0.99")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://gnu/classpath/classpath-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "1j7cby4k66f1nvckm48xcmh352b1d1b33qk7l6hi7dp9i9zjjagr"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags
       (list (string-append "--with-ecj-jar="
                            (assoc-ref %build-inputs "ecj-bootstrap")
                            "/share/java/ecj-bootstrap.jar")
             (string-append "JAVAC="
                            (assoc-ref %build-inputs "ecj-javac-wrapper")
                            "/bin/javac")
             (string-append "JAVA="
                            (assoc-ref %build-inputs "sablevm")
                            "/bin/java-sablevm")
             "GCJ_JAVAC_TRUE=no"
             "ac_cv_prog_java_works=yes"  ; trust me
             "--disable-Werror"
             "--disable-gmp"
             "--disable-gtk-peer"
             "--disable-gconf-peer"
             "--disable-plugin"
             "--disable-dssi"
             "--disable-alsa"
             "--disable-gjdoc")
       #:phases
       (modify-phases %standard-phases
         (add-after 'install 'install-data
           (lambda _ (zero? (system* "make" "install-data")))))))
    (native-inputs
     `(("ecj-bootstrap" ,ecj-bootstrap)
       ("ecj-javac-wrapper" ,ecj-javac-wrapper)
       ("fastjar" ,fastjar)
       ("sablevm" ,sablevm)
       ("sablevm-classpath" ,sablevm-classpath)
       ("libltdl" ,libltdl)
       ("pkg-config" ,pkg-config)))
    (home-page "https://www.gnu.org/software/classpath/")
    (synopsis "Essential libraries for Java")
    (description "GNU Classpath is a project to create core class libraries
for use with runtimes, compilers and tools for the Java programming
language.")
    ;; GPLv2 or later, with special linking exception.
    (license license:gpl2+)))

(define jamvm-bootstrap
  (package
    (name "jamvm")
    (version "2.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/jamvm/jamvm/"
                                  "JamVM%20" version "/jamvm-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "1nl0zxz8y5x8gwsrm7n32bry4dx8x70p8z3s9jbdvs8avyb8whkn"))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags
       (list (string-append "--with-classpath-install-dir="
                            (assoc-ref %build-inputs "classpath")))))
    (inputs
     `(("classpath" ,classpath-on-sablevm)
       ("ecj-javac-wrapper" ,ecj-javac-wrapper)
       ("zlib" ,zlib)))
    (home-page "http://jamvm.sourceforge.net/")
    (synopsis "Small Java Virtual Machine")
    (description "JamVM is a Java Virtual Machine conforming to the JVM
specification edition 2 (blue book).  It is extremely small.  However, unlike
other small VMs it supports the full spec, including object finalisation and
JNI.")
    (license license:gpl2+)))

;; We need this because the tools provided by the latest release of GNU
;; Classpath don't actually work with sablevm.
(define classpath-jamvm-wrappers
  (package (inherit classpath-on-sablevm)
    (name "classpath-jamvm-wrappers")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((bash      (assoc-ref %build-inputs "bash"))
                (jamvm     (assoc-ref %build-inputs "jamvm"))
                (classpath (assoc-ref %build-inputs "classpath"))
                (bin       (string-append (assoc-ref %outputs "out")
                                          "/bin/")))
           (mkdir-p bin)
           (for-each (lambda (tool)
                       (with-output-to-file (string-append bin tool)
                         (lambda _
                           (format #t "#!~a/bin/sh
~a/bin/jamvm -classpath ~a/share/classpath/tools.zip \
gnu.classpath.tools.~a.~a $@"
                                   bash jamvm classpath tool
                                   (if (string=? "native2ascii" tool)
                                       "Native2ASCII" "Main"))))
                       (chmod (string-append bin tool) #o755))
                     (list "javah"
                           "rmic"
                           "rmid"
                           "orbd"
                           "rmiregistry"
                           "native2ascii"))
           #t))))
    (native-inputs
     `(("bash" ,bash)
       ("jamvm" ,jamvm-bootstrap)
       ("classpath" ,classpath-on-sablevm)))
    (inputs '())
    (synopsis "Executables from GNU Classpath")
    (description "This package provides wrappers around the tools provided by
the GNU Classpath library.  They are executed by the JamVM virtual
machine.")))

(define ecj-javac-on-jamvm-wrapper
  (package (inherit ecj-javac-wrapper)
    (name "ecj-javac-on-jamvm-wrapper")
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       ;; TODO: This builder is exactly the same as in ecj-javac-wrapper,
       ;; except that the backend is 'jamvm here.  Can we reuse the same
       ;; builder somehow?
       (let ((backend 'jamvm))
         (use-modules (guix build utils))
         (let* ((bin    (string-append (assoc-ref %outputs "out") "/bin"))
                (target (string-append bin "/javac"))
                (guile  (string-append (assoc-ref %build-inputs "guile")
                                       "/bin/guile"))
                (ecj    (string-append (assoc-ref %build-inputs "ecj-bootstrap")
                                       "/share/java/ecj-bootstrap.jar"))
                (java   (case backend
                          ((sablevm)
                           (string-append (assoc-ref %build-inputs "sablevm")
                                          "/lib/sablevm/bin/java"))
                          ((jamvm)
                           (string-append (assoc-ref %build-inputs "jamvm")
                                          "/bin/jamvm"))))
                (bootcp (case backend
                          ((sablevm)
                           (let ((jvmlib (string-append
                                          (assoc-ref %build-inputs "sablevm-classpath")
                                          "/lib/sablevm")))
                             (string-append jvmlib "/jre/lib/rt.jar")))
                          ((jamvm)
                           (let ((jvmlib (string-append (assoc-ref %build-inputs "classpath")
                                                        "/share/classpath")))
                             (string-append jvmlib "/lib/glibj.zip:"
                                            jvmlib "/lib/tools.zip"))))))
           (mkdir-p bin)
           (with-output-to-file target
             (lambda _
               (format #t "#!~a --no-auto-compile\n!#\n" guile)
               (write
                `(begin (use-modules (ice-9 match)
                                     (ice-9 receive)
                                     (ice-9 hash-table)
                                     (srfi srfi-1)
                                     (srfi srfi-26))
                        (define defaults
                          '(("-bootclasspath" ,bootcp)
                            ("-source" "1.5")
                            ("-target" "1.5")
                            ("-cp"     ".")))
                        (define (main args)
                          (let ((classpath (getenv "CLASSPATH")))
                            (setenv "CLASSPATH"
                                    (string-append ,ecj
                                                   (if classpath
                                                       (string-append ":" classpath)
                                                       ""))))
                          (receive (vm-args other-args)
                              ;; Separate VM arguments from arguments to ECJ.
                              (partition (cut string-prefix? "-J" <>)
                                         (fold (lambda (default acc)
                                                 (if (member (first default) acc)
                                                     acc (append default acc)))
                                               args defaults))
                            (apply system* ,java
                                   (append
                                    ;; Remove "-J" prefix
                                    (map (cut string-drop <> 2) vm-args)
                                    '("org.eclipse.jdt.internal.compiler.batch.Main")
                                    (cons "-nowarn" other-args)))))
                        ;; Entry point
                        (let ((args (cdr (command-line))))
                          (if (null? args)
                              (format (current-error-port) "javac: no arguments given!\n")
                              (main args)))))))
           (chmod target #o755)
           #t))))
    (native-inputs
     `(("guile" ,guile-2.2)
       ("ecj-bootstrap" ,ecj-bootstrap)
       ("jamvm" ,jamvm-bootstrap)
       ("classpath" ,classpath-on-sablevm)))
    (description "This package provides a wrapper around the @dfn{Eclipse
compiler for Java} (ecj) with a command line interface that is compatible with
the standard javac executable.  The tool runs on JamVM instead of SableVM.")))

;; The last release of GNU Classpath is 0.99 and it happened in 2012.  Since
;; then Classpath has gained much more support for Java 1.6.
(define-public classpath-devel
  (let ((commit "e7c13ee0cf2005206fbec0eca677f8cf66d5a103")
        (revision "1"))
    (package (inherit classpath-on-sablevm)
      (version (string-append "0.99-" revision "." (string-take commit 9)))
      (source (origin
                (method git-fetch)
                (uri (git-reference
                      (url "https://git.savannah.gnu.org/git/classpath.git")
                      (commit commit)))
                (file-name (string-append "classpath-" version "-checkout"))
                (sha256
                 (base32
                  "1v2rww76ww322mpg3s12a1kkc6gkp31bm9gcxs532h0wq285fiw4"))))
      (arguments
       `(#:make-flags
         ;; Ensure that the initial heap size is smaller than the maximum
         ;; size.  By default only Xmx is set, which can lead to invalid
         ;; memory settings on some machines with a lot of memory.
         '("JAVAC_MEM_OPT=-J-Xms512M -J-Xmx768M")
         #:configure-flags
         (list (string-append "--with-ecj-jar="
                              (assoc-ref %build-inputs "ecj-bootstrap")
                              "/share/java/ecj-bootstrap.jar")
               (string-append "--with-javac="
                              (assoc-ref %build-inputs "ecj-javac-wrapper")
                              "/bin/javac")
               (string-append "JAVA="
                              (assoc-ref %build-inputs "jamvm")
                              "/bin/jamvm")
               "GCJ_JAVAC_TRUE=no"
               "ac_cv_prog_java_works=yes" ; trust me
               "--disable-Werror"
               "--disable-gmp"
               "--disable-gtk-peer"
               "--disable-gconf-peer"
               "--disable-plugin"
               "--disable-dssi"
               "--disable-alsa"
               "--disable-gjdoc")
         #:phases
         (modify-phases %standard-phases
           (add-after 'unpack 'bootstrap
             (lambda _
               (zero? (system* "autoreconf" "-vif"))))
           (add-after 'unpack 'remove-unsupported-annotations
             (lambda _
               (substitute* (find-files "java" "\\.java$")
                 (("@Override") ""))
               #t))
           (add-after 'install 'install-data
             (lambda _ (zero? (system* "make" "install-data")))))))
      (native-inputs
       `(("autoconf" ,autoconf)
         ("automake" ,automake)
         ("libtool" ,libtool)
         ("gettext" ,gettext-minimal)
         ("texinfo" ,texinfo)
         ("classpath-jamvm-wrappers" ,classpath-jamvm-wrappers) ; for javah
         ("ecj-bootstrap" ,ecj-bootstrap)
         ("ecj-javac-wrapper" ,ecj-javac-on-jamvm-wrapper)
         ("fastjar" ,fastjar)
         ("jamvm" ,jamvm-bootstrap)
         ("libltdl" ,libltdl)
         ("pkg-config" ,pkg-config))))))

(define-public jamvm
  (package (inherit jamvm-bootstrap)
    (inputs
     `(("classpath" ,classpath-devel)
       ("ecj-javac-wrapper" ,ecj-javac-on-jamvm-wrapper)
       ("zlib" ,zlib)))))

(define ecj-javac-on-jamvm-wrapper-final
  (package (inherit ecj-javac-on-jamvm-wrapper)
    (native-inputs
     `(("guile" ,guile-2.2)
       ("ecj-bootstrap" ,ecj-bootstrap)
       ("jamvm" ,jamvm)
       ("classpath" ,classpath-devel)))))

;; The bootstrap JDK consisting of jamvm, classpath-devel,
;; ecj-javac-on-jamvm-wrapper-final cannot build Icedtea 2.x directly, because
;; it's written in Java 7.  It can, however, build the unmaintained Icedtea
;; 1.x, which uses Java 6 only.
(define-public icedtea-6
  (package
    (name "icedtea")
    (version "1.13.13")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "http://icedtea.wildebeest.org/download/source/icedtea6-"
                    version ".tar.xz"))
              (sha256
               (base32
                "0bg9sb4f7qbq77c0zf9m17p47ga0kf0r9622g9p12ysg26jd1ksg"))
              (modules '((guix build utils)))
              (snippet
               '(substitute* "Makefile.in"
                  ;; do not leak information about the build host
                  (("DISTRIBUTION_ID=\"\\$\\(DIST_ID\\)\"")
                   "DISTRIBUTION_ID=\"\\\"guix\\\"\"")))))
    (build-system gnu-build-system)
    (outputs '("out"   ; Java Runtime Environment
               "jdk"   ; Java Development Kit
               "doc")) ; all documentation
    (arguments
     `(;; There are many failing tests and many are known to fail upstream.
       #:tests? #f

       ;; The DSOs use $ORIGIN to refer to each other, but (guix build
       ;; gremlin) doesn't support it yet, so skip this phase.
       #:validate-runpath? #f

       #:modules ((guix build utils)
                  (guix build gnu-build-system)
                  (srfi srfi-19))

       #:configure-flags
       `("--enable-bootstrap"
         "--enable-nss"
         "--without-rhino"
         "--with-parallel-jobs"
         "--disable-downloading"
         "--disable-tests"
         ,(string-append "--with-ecj="
                         (assoc-ref %build-inputs "ecj")
                         "/share/java/ecj-bootstrap.jar")
         ,(string-append "--with-jar="
                         (assoc-ref %build-inputs "fastjar")
                         "/bin/fastjar")
         ,(string-append "--with-jdk-home="
                         (assoc-ref %build-inputs "classpath"))
         ,(string-append "--with-java="
                         (assoc-ref %build-inputs "jamvm")
                         "/bin/jamvm"))
       #:phases
       (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source inputs #:allow-other-keys)
             (and (zero? (system* "tar" "xvf" source))
                  (begin
                    (chdir (string-append "icedtea6-" ,version))
                    (mkdir "openjdk")
                    (copy-recursively (assoc-ref inputs "openjdk-src") "openjdk")
                    ;; The convenient OpenJDK source bundle is no longer
                    ;; available for download, so we have to take the sources
                    ;; from the Mercurial repositories and change the Makefile
                    ;; to avoid tests for the OpenJDK zip archive.
                    (with-directory-excursion "openjdk"
                      (for-each (lambda (part)
                                  (mkdir part)
                                  (copy-recursively
                                   (assoc-ref inputs
                                              (string-append part "-src"))
                                   part))
                                '("jdk" "hotspot" "corba"
                                  "langtools" "jaxp" "jaxws")))
                    (substitute* "Makefile.in"
                      (("echo \"ERROR: No up-to-date OpenJDK zip available\"; exit -1;")
                       "echo \"trust me\";")
                      ;; The contents of the bootstrap directory must be
                      ;; writeable but when copying from the store they are
                      ;; not.
                      (("mkdir -p lib/rt" line)
                       (string-append line "; chmod -R u+w $(BOOT_DIR)")))
                    (zero? (system* "chmod" "-R" "u+w" "openjdk"))
                    #t))))
         (add-after 'unpack 'use-classpath
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((jvmlib (assoc-ref inputs "classpath")))
               ;; Classpath does not provide rt.jar.
               (substitute* "Makefile.in"
                 (("\\$\\(SYSTEM_JDK_DIR\\)/jre/lib/rt.jar")
                  (string-append jvmlib "/share/classpath/glibj.zip")))
               ;; Make sure we can find all classes.
               (setenv "CLASSPATH"
                       (string-append jvmlib "/share/classpath/glibj.zip:"
                                      jvmlib "/share/classpath/tools.zip"))
               (setenv "JAVACFLAGS"
                       (string-append "-cp "
                                      jvmlib "/share/classpath/glibj.zip:"
                                      jvmlib "/share/classpath/tools.zip")))
             #t))
         (add-after 'unpack 'patch-patches
           (lambda _
             ;; shebang in patches so that they apply cleanly
             (substitute* '("patches/jtreg-jrunscript.patch"
                            "patches/hotspot/hs23/drop_unlicensed_test.patch")
               (("#!/bin/sh") (string-append "#!" (which "sh"))))
             #t))
         (add-after 'unpack 'patch-paths
           (lambda* (#:key inputs #:allow-other-keys)
             ;; buildtree.make generates shell scripts, so we need to replace
             ;; the generated shebang
             (substitute* '("openjdk/hotspot/make/linux/makefiles/buildtree.make")
               (("/bin/sh") (which "bash")))

             (let ((corebin (string-append
                             (assoc-ref inputs "coreutils") "/bin/"))
                   (binbin  (string-append
                             (assoc-ref inputs "binutils") "/bin/"))
                   (grepbin (string-append
                             (assoc-ref inputs "grep") "/bin/")))
               (substitute* '("openjdk/jdk/make/common/shared/Defs-linux.gmk"
                              "openjdk/corba/make/common/shared/Defs-linux.gmk")
                 (("UNIXCOMMAND_PATH  = /bin/")
                  (string-append "UNIXCOMMAND_PATH = " corebin))
                 (("USRBIN_PATH  = /usr/bin/")
                  (string-append "USRBIN_PATH = " corebin))
                 (("DEVTOOLS_PATH *= */usr/bin/")
                  (string-append "DEVTOOLS_PATH = " corebin))
                 (("COMPILER_PATH *= */usr/bin/")
                  (string-append "COMPILER_PATH = "
                                 (assoc-ref inputs "gcc") "/bin/"))
                 (("DEF_OBJCOPY *=.*objcopy")
                  (string-append "DEF_OBJCOPY = " (which "objcopy"))))

               ;; fix path to alsa header
               (substitute* "openjdk/jdk/make/common/shared/Sanity.gmk"
                 (("ALSA_INCLUDE=/usr/include/alsa/version.h")
                  (string-append "ALSA_INCLUDE="
                                 (assoc-ref inputs "alsa-lib")
                                 "/include/alsa/version.h")))

               ;; fix hard-coded utility paths
               (substitute* '("openjdk/jdk/make/common/shared/Defs-utils.gmk"
                              "openjdk/corba/make/common/shared/Defs-utils.gmk")
                 (("ECHO *=.*echo")
                  (string-append "ECHO = " (which "echo")))
                 (("^GREP *=.*grep")
                  (string-append "GREP = " (which "grep")))
                 (("EGREP *=.*egrep")
                  (string-append "EGREP = " (which "egrep")))
                 (("CPIO *=.*cpio")
                  (string-append "CPIO = " (which "cpio")))
                 (("READELF *=.*readelf")
                  (string-append "READELF = " (which "readelf")))
                 (("^ *AR *=.*ar")
                  (string-append "AR = " (which "ar")))
                 (("^ *TAR *=.*tar")
                  (string-append "TAR = " (which "tar")))
                 (("AS *=.*as")
                  (string-append "AS = " (which "as")))
                 (("LD *=.*ld")
                  (string-append "LD = " (which "ld")))
                 (("STRIP *=.*strip")
                  (string-append "STRIP = " (which "strip")))
                 (("NM *=.*nm")
                  (string-append "NM = " (which "nm")))
                 (("^SH *=.*sh")
                  (string-append "SH = " (which "bash")))
                 (("^FIND *=.*find")
                  (string-append "FIND = " (which "find")))
                 (("LDD *=.*ldd")
                  (string-append "LDD = " (which "ldd")))
                 (("NAWK *=.*(n|g)awk")
                  (string-append "NAWK = " (which "gawk")))
                 (("XARGS *=.*xargs")
                  (string-append "XARGS = " (which "xargs")))
                 (("UNZIP *=.*unzip")
                  (string-append "UNZIP = " (which "unzip")))
                 (("ZIPEXE *=.*zip")
                  (string-append "ZIPEXE = " (which "zip")))
                 (("SED *=.*sed")
                  (string-append "SED = " (which "sed"))))

               ;; Some of these timestamps cause problems as they are more than
               ;; 10 years ago, failing the build process.
               (substitute*
                   "openjdk/jdk/src/share/classes/java/util/CurrencyData.properties"
                 (("AZ=AZM;2005-12-31-20-00-00;AZN") "AZ=AZN")
                 (("MZ=MZM;2006-06-30-22-00-00;MZN") "MZ=MZN")
                 (("RO=ROL;2005-06-30-21-00-00;RON") "RO=RON")
                 (("TR=TRL;2004-12-31-22-00-00;TRY") "TR=TRY"))
               #t)))
         (add-before 'configure 'set-additional-paths
           (lambda* (#:key inputs #:allow-other-keys)
             (setenv "CPATH"
                     (string-append (assoc-ref inputs "libxrender")
                                    "/include/X11/extensions" ":"
                                    (assoc-ref inputs "libxtst")
                                    "/include/X11/extensions" ":"
                                    (assoc-ref inputs "libxinerama")
                                    "/include/X11/extensions" ":"
                                    (or (getenv "CPATH") "")))
             (setenv "ALT_CUPS_HEADERS_PATH"
                     (string-append (assoc-ref inputs "cups")
                                    "/include"))
             (setenv "ALT_FREETYPE_HEADERS_PATH"
                     (string-append (assoc-ref inputs "freetype")
                                    "/include"))
             (setenv "ALT_FREETYPE_LIB_PATH"
                     (string-append (assoc-ref inputs "freetype")
                                    "/lib"))
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((doc (string-append (assoc-ref outputs "doc")
                                       "/share/doc/icedtea"))
                   (jre (assoc-ref outputs "out"))
                   (jdk (assoc-ref outputs "jdk")))
               (copy-recursively "openjdk.build/docs" doc)
               (copy-recursively "openjdk.build/j2re-image" jre)
               (copy-recursively "openjdk.build/j2sdk-image" jdk))
             #t)))))
    (native-inputs
     `(("ant" ,ant-bootstrap)
       ("alsa-lib" ,alsa-lib)
       ("attr" ,attr)
       ("classpath" ,classpath-devel)
       ("coreutils" ,coreutils)
       ("cpio" ,cpio)
       ("cups" ,cups)
       ("ecj" ,ecj-bootstrap)
       ("ecj-javac" ,ecj-javac-on-jamvm-wrapper-final)
       ("fastjar" ,fastjar)
       ("fontconfig" ,fontconfig)
       ("freetype" ,freetype)
       ("gtk" ,gtk+-2)
       ("gawk" ,gawk)
       ("giflib" ,giflib)
       ("grep" ,grep)
       ("jamvm" ,jamvm)
       ("lcms" ,lcms)
       ("libjpeg" ,libjpeg)
       ("libpng" ,libpng)
       ("libtool" ,libtool)
       ("libx11" ,libx11)
       ("libxcomposite" ,libxcomposite)
       ("libxi" ,libxi)
       ("libxinerama" ,libxinerama)
       ("libxrender" ,libxrender)
       ("libxslt" ,libxslt) ;for xsltproc
       ("libxt" ,libxt)
       ("libxtst" ,libxtst)
       ("mit-krb5" ,mit-krb5)
       ("nss" ,nss)
       ("nss-certs" ,nss-certs)
       ("perl" ,perl)
       ("pkg-config" ,pkg-config)
       ("procps" ,procps) ;for "free", even though I'm not sure we should use it
       ("unzip" ,unzip)
       ("wget" ,wget)
       ("which" ,which)
       ("zip" ,zip)
       ("zlib" ,zlib)
       ("openjdk-src"
        ,(origin
           (method hg-fetch)
           (uri (hg-reference
                 (url "http://hg.openjdk.java.net/jdk6/jdk6/")
                 (changeset "jdk6-b41")))
           (sha256
            (base32
             "14q47yfg586fs64w30g8mk92m5dkxsvr36zzh0ra99xk5x0x96mv"))))
       ("jdk-src"
        ,(origin
           (method hg-fetch)
           (uri (hg-reference
                 (url "http://hg.openjdk.java.net/jdk6/jdk6/jdk/")
                 (changeset "jdk6-b41")))
           (sha256
            (base32
             "165824nhg1k1dx6zs9dny0j49rmk35jw5b13dmz8c77jfajml4v9"))))
       ("hotspot-src"
        ,(origin
           (method hg-fetch)
           (uri (hg-reference
                 (url "http://hg.openjdk.java.net/jdk6/jdk6/hotspot/")
                 (changeset "jdk6-b41")))
           (sha256
            (base32
             "07lc1z4k5dj9nrc1wvwmpvxr3xgxrdkdh53xb95skk5ij49yagfd"))))
       ("corba-src"
        ,(origin
           (method hg-fetch)
           (uri (hg-reference
                 (url "http://hg.openjdk.java.net/jdk6/jdk6/corba/")
                 (changeset "jdk6-b41")))
           (sha256
            (base32
             "1p9g1r9dnax2iwp7yb59qx7m4nmshqhwmrb2b8jj8zgbd9dl2i3q"))))
       ("langtools-src"
        ,(origin
           (method hg-fetch)
           (uri (hg-reference
                 (url "http://hg.openjdk.java.net/jdk6/jdk6/langtools/")
                 (changeset "jdk6-b41")))
           (sha256
            (base32
             "1x52wd67fynbbd9ild6fb4wvba3f5hhwk03qdjfazd0a1qr37z3d"))))
       ("jaxp-src"
        ,(origin
           (method hg-fetch)
           (uri (hg-reference
                 (url "http://hg.openjdk.java.net/jdk6/jdk6/jaxp/")
                 (changeset "jdk6-b41")))
           (sha256
            (base32
             "0shlqrvzpr4nrkmv215lbxnby63s3yvbdh1yxcayznsyqwa4nlxm"))))
       ("jaxws-src"
        ,(origin
           (method hg-fetch)
           (uri (hg-reference
                 (url "http://hg.openjdk.java.net/jdk6/jdk6/jaxws/")
                 (changeset "jdk6-b41")))
           (sha256
            (base32
             "0835lkw8vib1xhp8lxnybhlvzdh699hbi4mclxanydjk63zbpxk0"))))))
    (home-page "http://icedtea.classpath.org")
    (synopsis "Java development kit")
    (description
     "This package provides the OpenJDK built with the IcedTea build harness.
This version of the OpenJDK is no longer maintained and is only used for
bootstrapping purposes.")
    ;; IcedTea is released under the GPL2 + Classpath exception, which is the
    ;; same license as both GNU Classpath and OpenJDK.
    (license license:gpl2+)))

(define-public icedtea-7
  (let* ((version "2.6.11")
         (drop (lambda (name hash)
                 (origin
                   (method url-fetch)
                   (uri (string-append
                         "http://icedtea.classpath.org/download/drops"
                         "/icedtea7/" version "/" name ".tar.bz2"))
                   (sha256 (base32 hash))))))
    (package
      (name "icedtea")
      (version version)
      (source (origin
                (method url-fetch)
                (uri (string-append
                      "http://icedtea.wildebeest.org/download/source/icedtea-"
                      version ".tar.xz"))
                (sha256
                 (base32
                  "1ibp6ybqnf8g7mbs45bkbv44dwz4h2w9gr4rh15yvr1m8lqkq1i0"))
                (modules '((guix build utils)))
                (snippet
                 '(substitute* "Makefile.in"
                    ;; do not leak information about the build host
                    (("DISTRIBUTION_ID=\"\\$\\(DIST_ID\\)\"")
                     "DISTRIBUTION_ID=\"\\\"guix\\\"\"")))))
      (build-system gnu-build-system)
      (outputs '("out"   ; Java Runtime Environment
                 "jdk"   ; Java Development Kit
                 "doc")) ; all documentation
      (arguments
       `(;; There are many test failures.  Some are known to
         ;; fail upstream, others relate to not having an X
         ;; server running at test time, yet others are a
         ;; complete mystery to me.

         ;; hotspot:   passed: 241; failed: 45; error: 2
         ;; langtools: passed: 1,934; failed: 26
         ;; jdk:       unknown
         #:tests? #f

         ;; The DSOs use $ORIGIN to refer to each other, but (guix build
         ;; gremlin) doesn't support it yet, so skip this phase.
         #:validate-runpath? #f

         ;; Apparently, the C locale is needed for some of the tests.
         #:locale "C"

         #:modules ((guix build utils)
                    (guix build gnu-build-system)
                    (ice-9 match)
                    (ice-9 popen)
                    (srfi srfi-19)
                    (srfi srfi-26))

         #:configure-flags
         ;; TODO: package pcsc and sctp, and add to inputs
         `("--disable-system-pcsc"
           "--disable-system-sctp"
           "--enable-bootstrap"
           "--enable-nss"
           "--without-rhino"
           "--disable-downloading"
           "--disable-tests"        ;they are run in the check phase instead
           "--with-openjdk-src-dir=./openjdk.src"
           ,(string-append "--with-jdk-home="
                           (assoc-ref %build-inputs "jdk")))

         #:phases
         (modify-phases %standard-phases
           (replace 'unpack
             (lambda* (#:key source inputs #:allow-other-keys)
               (let ((target (string-append "icedtea-" ,version))
                     (unpack (lambda* (name #:optional dir)
                               (let ((dir (or dir
                                              (string-drop-right name 5))))
                                 (mkdir dir)
                                 (zero? (system* "tar" "xvf"
                                                 (assoc-ref inputs name)
                                                 "-C" dir
                                                 "--strip-components=1"))))))
                 (mkdir target)
                 (and
                  (zero? (system* "tar" "xvf" source
                                  "-C" target "--strip-components=1"))
                  (chdir target)
                  (unpack "openjdk-src" "openjdk.src")
                  (with-directory-excursion "openjdk.src"
                    (for-each unpack
                              (filter (cut string-suffix? "-drop" <>)
                                      (map (match-lambda
                                             ((name . _) name))
                                           inputs))))
                  #t))))
           (add-after 'unpack 'fix-x11-extension-include-path
             (lambda* (#:key inputs #:allow-other-keys)
               (substitute* "openjdk.src/jdk/make/sun/awt/mawt.gmk"
                 (((string-append "\\$\\(firstword \\$\\(wildcard "
                                  "\\$\\(OPENWIN_HOME\\)"
                                  "/include/X11/extensions\\).*$"))
                  (string-append (assoc-ref inputs "libxrender")
                                 "/include/X11/extensions"
                                 " -I" (assoc-ref inputs "libxtst")
                                 "/include/X11/extensions"
                                 " -I" (assoc-ref inputs "libxinerama")
                                 "/include/X11/extensions"))
                 (("\\$\\(wildcard /usr/include/X11/extensions\\)\\)") ""))
               #t))
           (add-after 'unpack 'patch-paths
             (lambda _
               ;; buildtree.make generates shell scripts, so we need to replace
               ;; the generated shebang
               (substitute* '("openjdk.src/hotspot/make/linux/makefiles/buildtree.make")
                 (("/bin/sh") (which "bash")))

               (let ((corebin (string-append
                               (assoc-ref %build-inputs "coreutils") "/bin/"))
                     (binbin  (string-append
                               (assoc-ref %build-inputs "binutils") "/bin/"))
                     (grepbin (string-append
                               (assoc-ref %build-inputs "grep") "/bin/")))
                 (substitute* '("openjdk.src/jdk/make/common/shared/Defs-linux.gmk"
                                "openjdk.src/corba/make/common/shared/Defs-linux.gmk")
                   (("UNIXCOMMAND_PATH  = /bin/")
                    (string-append "UNIXCOMMAND_PATH = " corebin))
                   (("USRBIN_PATH  = /usr/bin/")
                    (string-append "USRBIN_PATH = " corebin))
                   (("DEVTOOLS_PATH *= */usr/bin/")
                    (string-append "DEVTOOLS_PATH = " corebin))
                   (("COMPILER_PATH *= */usr/bin/")
                    (string-append "COMPILER_PATH = "
                                   (assoc-ref %build-inputs "gcc") "/bin/"))
                   (("DEF_OBJCOPY *=.*objcopy")
                    (string-append "DEF_OBJCOPY = " (which "objcopy"))))

                 ;; fix path to alsa header
                 (substitute* "openjdk.src/jdk/make/common/shared/Sanity.gmk"
                   (("ALSA_INCLUDE=/usr/include/alsa/version.h")
                    (string-append "ALSA_INCLUDE="
                                   (assoc-ref %build-inputs "alsa-lib")
                                   "/include/alsa/version.h")))

                 ;; fix hard-coded utility paths
                 (substitute* '("openjdk.src/jdk/make/common/shared/Defs-utils.gmk"
                                "openjdk.src/corba/make/common/shared/Defs-utils.gmk")
                   (("ECHO *=.*echo")
                    (string-append "ECHO = " (which "echo")))
                   (("^GREP *=.*grep")
                    (string-append "GREP = " (which "grep")))
                   (("EGREP *=.*egrep")
                    (string-append "EGREP = " (which "egrep")))
                   (("CPIO *=.*cpio")
                    (string-append "CPIO = " (which "cpio")))
                   (("READELF *=.*readelf")
                    (string-append "READELF = " (which "readelf")))
                   (("^ *AR *=.*ar")
                    (string-append "AR = " (which "ar")))
                   (("^ *TAR *=.*tar")
                    (string-append "TAR = " (which "tar")))
                   (("AS *=.*as")
                    (string-append "AS = " (which "as")))
                   (("LD *=.*ld")
                    (string-append "LD = " (which "ld")))
                   (("STRIP *=.*strip")
                    (string-append "STRIP = " (which "strip")))
                   (("NM *=.*nm")
                    (string-append "NM = " (which "nm")))
                   (("^SH *=.*sh")
                    (string-append "SH = " (which "bash")))
                   (("^FIND *=.*find")
                    (string-append "FIND = " (which "find")))
                   (("LDD *=.*ldd")
                    (string-append "LDD = " (which "ldd")))
                   (("NAWK *=.*(n|g)awk")
                    (string-append "NAWK = " (which "gawk")))
                   (("XARGS *=.*xargs")
                    (string-append "XARGS = " (which "xargs")))
                   (("UNZIP *=.*unzip")
                    (string-append "UNZIP = " (which "unzip")))
                   (("ZIPEXE *=.*zip")
                    (string-append "ZIPEXE = " (which "zip")))
                   (("SED *=.*sed")
                    (string-append "SED = " (which "sed"))))

                 ;; Some of these timestamps cause problems as they are more than
                 ;; 10 years ago, failing the build process.
                 (substitute*
                     "openjdk.src/jdk/src/share/classes/java/util/CurrencyData.properties"
                   (("AZ=AZM;2005-12-31-20-00-00;AZN") "AZ=AZN")
                   (("MZ=MZM;2006-06-30-22-00-00;MZN") "MZ=MZN")
                   (("RO=ROL;2005-06-30-21-00-00;RON") "RO=RON")
                   (("TR=TRL;2004-12-31-22-00-00;TRY") "TR=TRY")))
               #t))
           (add-before 'configure 'set-additional-paths
             (lambda* (#:key inputs #:allow-other-keys)
               (substitute* "openjdk.src/jdk/make/common/shared/Sanity.gmk"
                 (("ALSA_INCLUDE=/usr/include/alsa/version.h")
                  (string-append "ALSA_INCLUDE="
                                 (assoc-ref inputs "alsa-lib")
                                 "/include/alsa/version.h")))
               (setenv "CC" "gcc")
               (setenv "CPATH"
                       (string-append (assoc-ref inputs "libxcomposite")
                                      "/include/X11/extensions" ":"
                                      (assoc-ref inputs "libxrender")
                                      "/include/X11/extensions" ":"
                                      (assoc-ref inputs "libxtst")
                                      "/include/X11/extensions" ":"
                                      (assoc-ref inputs "libxinerama")
                                      "/include/X11/extensions" ":"
                                      (or (getenv "CPATH") "")))
               (setenv "ALT_OBJCOPY" (which "objcopy"))
               (setenv "ALT_CUPS_HEADERS_PATH"
                       (string-append (assoc-ref inputs "cups")
                                      "/include"))
               (setenv "ALT_FREETYPE_HEADERS_PATH"
                       (string-append (assoc-ref inputs "freetype")
                                      "/include"))
               (setenv "ALT_FREETYPE_LIB_PATH"
                       (string-append (assoc-ref inputs "freetype")
                                      "/lib"))
               #t))
           (add-before 'check 'fix-test-framework
             (lambda _
               ;; Fix PATH in test environment
               (substitute* "test/jtreg/com/sun/javatest/regtest/Main.java"
                 (("PATH=/bin:/usr/bin")
                  (string-append "PATH=" (getenv "PATH"))))
               (substitute* "test/jtreg/com/sun/javatest/util/SysEnv.java"
                 (("/usr/bin/env") (which "env")))
               (substitute* "openjdk.src/hotspot/test/test_env.sh"
                 (("/bin/rm") (which "rm"))
                 (("/bin/cp") (which "cp"))
                 (("/bin/mv") (which "mv")))
               #t))
           (add-before 'check 'fix-hotspot-tests
             (lambda _
               (with-directory-excursion "openjdk.src/hotspot/test/"
                 (substitute* "jprt.config"
                   (("PATH=\"\\$\\{path4sdk\\}\"")
                    (string-append "PATH=" (getenv "PATH")))
                   (("make=/usr/bin/make")
                    (string-append "make=" (which "make"))))
                 (substitute* '("runtime/6626217/Test6626217.sh"
                                "runtime/7110720/Test7110720.sh")
                   (("/bin/rm") (which "rm"))
                   (("/bin/cp") (which "cp"))
                   (("/bin/mv") (which "mv"))))
               #t))
           (add-before 'check 'fix-jdk-tests
             (lambda _
               (with-directory-excursion "openjdk.src/jdk/test/"
                 (substitute* "com/sun/jdi/JdbReadTwiceTest.sh"
                   (("/bin/pwd") (which "pwd")))
                 (substitute* "com/sun/jdi/ShellScaffold.sh"
                   (("/bin/kill") (which "kill")))
                 (substitute* "start-Xvfb.sh"
                   ;;(("/usr/bin/X11/Xvfb") (which "Xvfb"))
                   (("/usr/bin/nohup")    (which "nohup")))
                 (substitute* "javax/security/auth/Subject/doAs/Test.sh"
                   (("/bin/rm") (which "rm")))
                 (substitute* "tools/launcher/MultipleJRE.sh"
                   (("echo \"#!/bin/sh\"")
                    (string-append "echo \"#!" (which "rm") "\""))
                   (("/usr/bin/zip") (which "zip")))
                 (substitute* "com/sun/jdi/OnThrowTest.java"
                   (("#!/bin/sh") (string-append "#!" (which "sh"))))
                 (substitute* "java/lang/management/OperatingSystemMXBean/GetSystemLoadAverage.java"
                   (("/usr/bin/uptime") (which "uptime")))
                 (substitute* "java/lang/ProcessBuilder/Basic.java"
                   (("/usr/bin/env") (which "env"))
                   (("/bin/false") (which "false"))
                   (("/bin/true") (which "true"))
                   (("/bin/cp") (which "cp"))
                   (("/bin/sh") (which "sh")))
                 (substitute* "java/lang/ProcessBuilder/FeelingLucky.java"
                   (("/bin/sh") (which "sh")))
                 (substitute* "java/lang/ProcessBuilder/Zombies.java"
                   (("/usr/bin/perl") (which "perl"))
                   (("/bin/ps") (which "ps"))
                   (("/bin/true") (which "true")))
                 (substitute* "java/lang/Runtime/exec/ConcurrentRead.java"
                   (("/usr/bin/tee") (which "tee")))
                 (substitute* "java/lang/Runtime/exec/ExecWithDir.java"
                   (("/bin/true") (which "true")))
                 (substitute* "java/lang/Runtime/exec/ExecWithInput.java"
                   (("/bin/cat") (which "cat")))
                 (substitute* "java/lang/Runtime/exec/ExitValue.java"
                   (("/bin/sh") (which "sh"))
                   (("/bin/true") (which "true"))
                   (("/bin/kill") (which "kill")))
                 (substitute* "java/lang/Runtime/exec/LotsOfDestroys.java"
                   (("/usr/bin/echo") (which "echo")))
                 (substitute* "java/lang/Runtime/exec/LotsOfOutput.java"
                   (("/usr/bin/cat") (which "cat")))
                 (substitute* "java/lang/Runtime/exec/SleepyCat.java"
                   (("/bin/cat") (which "cat"))
                   (("/bin/sleep") (which "sleep"))
                   (("/bin/sh") (which "sh")))
                 (substitute* "java/lang/Runtime/exec/StreamsSurviveDestroy.java"
                   (("/bin/cat") (which "cat")))
                 (substitute* "java/rmi/activation/CommandEnvironment/SetChildEnv.java"
                   (("/bin/chmod") (which "chmod")))
                 (substitute* "java/util/zip/ZipFile/Assortment.java"
                   (("/bin/sh") (which "sh"))))
               #t))
           (replace 'check
             (lambda _
               ;; The "make check-*" targets always return zero, so we need to
               ;; check for errors in the associated log files to determine
               ;; whether any tests have failed.
               (use-modules (ice-9 rdelim))
               (let* ((error-pattern (make-regexp "^(Error|FAILED):.*"))
                      (checker (lambda (port)
                                 (let loop ()
                                   (let ((line (read-line port)))
                                     (cond
                                      ((eof-object? line) #t)
                                      ((regexp-exec error-pattern line) #f)
                                      (else (loop)))))))
                      (run-test (lambda (test)
                                  (system* "make" test)
                                  (call-with-input-file
                                      (string-append "test/" test ".log")
                                    checker))))
                 (or #t                 ; skip tests
                     (and (run-test "check-hotspot")
                          (run-test "check-langtools")
                          (run-test "check-jdk"))))))
           (replace 'install
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((doc (string-append (assoc-ref outputs "doc")
                                         "/share/doc/icedtea"))
                     (jre (assoc-ref outputs "out"))
                     (jdk (assoc-ref outputs "jdk")))
                 (copy-recursively "openjdk.build/docs" doc)
                 (copy-recursively "openjdk.build/j2re-image" jre)
                 (copy-recursively "openjdk.build/j2sdk-image" jdk))
               #t))
           ;; By default IcedTea only generates an empty keystore.  In order to
           ;; be able to use certificates in Java programs we need to generate a
           ;; keystore from a set of certificates.  For convenience we use the
           ;; certificates from the nss-certs package.
           (add-after 'install 'install-keystore
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let* ((keystore  "cacerts")
                      (certs-dir (string-append (assoc-ref inputs "nss-certs")
                                                "/etc/ssl/certs"))
                      (keytool   (string-append (assoc-ref outputs "jdk")
                                                "/bin/keytool")))
                 (define (extract-cert file target)
                   (call-with-input-file file
                     (lambda (in)
                       (call-with-output-file target
                         (lambda (out)
                           (let loop ((line (read-line in 'concat))
                                      (copying? #f))
                             (cond
                              ((eof-object? line) #t)
                              ((string-prefix? "-----BEGIN" line)
                               (display line out)
                               (loop (read-line in 'concat) #t))
                              ((string-prefix? "-----END" line)
                               (display line out)
                               #t)
                              (else
                               (when copying? (display line out))
                               (loop (read-line in 'concat) copying?)))))))))
                 (define (import-cert cert)
                   (format #t "Importing certificate ~a\n" (basename cert))
                   (let ((temp "tmpcert"))
                     (extract-cert cert temp)
                     (let ((port (open-pipe* OPEN_WRITE keytool
                                             "-import"
                                             "-alias" (basename cert)
                                             "-keystore" keystore
                                             "-storepass" "changeit"
                                             "-file" temp)))
                       (display "yes\n" port)
                       (when (not (zero? (status:exit-val (close-pipe port))))
                         (format #t "failed to import ~a\n" cert)))
                     (delete-file temp)))

                 ;; This is necessary because the certificate directory contains
                 ;; files with non-ASCII characters in their names.
                 (setlocale LC_ALL "en_US.utf8")
                 (setenv "LC_ALL" "en_US.utf8")

                 (for-each import-cert (find-files certs-dir "\\.pem$"))
                 (mkdir-p (string-append (assoc-ref outputs "out")
                                         "/lib/security"))
                 (mkdir-p (string-append (assoc-ref outputs "jdk")
                                         "/jre/lib/security"))

                 ;; The cacerts files we are going to overwrite are chmod'ed as
                 ;; read-only (444) in icedtea-8 (which derives from this
                 ;; package).  We have to change this so we can overwrite them.
                 (chmod (string-append (assoc-ref outputs "out")
                                       "/lib/security/" keystore) #o644)
                 (chmod (string-append (assoc-ref outputs "jdk")
                                       "/jre/lib/security/" keystore) #o644)

                 (install-file keystore
                               (string-append (assoc-ref outputs "out")
                                              "/lib/security"))
                 (install-file keystore
                               (string-append (assoc-ref outputs "jdk")
                                              "/jre/lib/security"))
                 #t))))))
      (native-inputs
       `(("openjdk-src"
          ,(drop "openjdk"
                 "1zhr4l9kxnbzghcsgjk3vmih9qpg1wrr9qry7fx04l97svp1ylhd"))
         ("corba-drop"
          ,(drop "corba"
                 "108v15ncb2rnsyzgzncjlm1f57d1sv60zd9qbpas8kqmvpp8r0gz"))
         ("jaxp-drop"
          ,(drop "jaxp"
                 "0zcpcmm3g1s7m31glrbw3ys7azi97ixcvbyxd40y9xzdja3jyr52"))
         ("jaxws-drop"
          ,(drop "jaxws"
                 "1gkqm0p3sr8d0xpki3fhf7cvmgqxx8ambgl5f3jx2plfnhsg96d2"))
         ("jdk-drop"
          ,(drop "jdk"
                 "1d9fjnzdx4m6gwkvmj2n097ag0mvkhm3lldaxjki8x8c6a5clknf"))
         ("langtools-drop"
          ,(drop "langtools"
                 "0zscdp9arcq7gr8j7jq4m75gq0w1i3ryxpdnrc8fl0msh4w2s2k5"))
         ("hotspot-drop"
          ,(drop "hotspot"
                 "1y6vnssn5y50x27g4ypdb5wwpmi7zf7jdi8gqbymkwf6n8p5y1d6"))
         ("ant" ,ant-bootstrap)
         ("attr" ,attr)
         ("coreutils" ,coreutils)
         ("diffutils" ,diffutils)       ;for tests
         ("gawk" ,gawk)
         ("grep" ,grep)
         ("libtool" ,libtool)
         ("pkg-config" ,pkg-config)
         ("wget" ,wget)
         ("which" ,which)
         ("cpio" ,cpio)
         ("zip" ,zip)
         ("unzip" ,unzip)
         ("fastjar" ,fastjar)
         ("libxslt" ,libxslt)           ;for xsltproc
         ("nss-certs" ,nss-certs)
         ("perl" ,perl)
         ("procps" ,procps) ;for "free", even though I'm not sure we should use it
         ("jdk" ,icedtea-6 "jdk")))
      (inputs
       `(("alsa-lib" ,alsa-lib)
         ("cups" ,cups)
         ("libx11" ,libx11)
         ("libxcomposite" ,libxcomposite)
         ("libxt" ,libxt)
         ("libxtst" ,libxtst)
         ("libxi" ,libxi)
         ("libxinerama" ,libxinerama)
         ("libxrender" ,libxrender)
         ("libjpeg" ,libjpeg)
         ("libpng" ,libpng)
         ("mit-krb5" ,mit-krb5)
         ("nss" ,nss)
         ("giflib" ,giflib)
         ("fontconfig" ,fontconfig)
         ("freetype" ,freetype)
         ("lcms" ,lcms)
         ("zlib" ,zlib)
         ("gtk" ,gtk+-2)))
      (home-page "http://icedtea.classpath.org")
      (synopsis "Java development kit")
      (description
       "This package provides the Java development kit OpenJDK built with the
IcedTea build harness.")
      ;; IcedTea is released under the GPL2 + Classpath exception, which is the
      ;; same license as both GNU Classpath and OpenJDK.
      (license license:gpl2+))))

(define-public icedtea-8
  (let* ((version "3.5.1")
         (drop (lambda (name hash)
                 (origin
                   (method url-fetch)
                   (uri (string-append
                         "http://icedtea.classpath.org/download/drops"
                         "/icedtea8/" version "/" name ".tar.xz"))
                   (sha256 (base32 hash))))))
    (package (inherit icedtea-7)
      (version "3.5.1")
      (source (origin
                (method url-fetch)
                (uri (string-append
                      "http://icedtea.wildebeest.org/download/source/icedtea-"
                      version ".tar.xz"))
                (sha256
                 (base32
                  "1j8iv0cdk9fkh3yb5is7z29m9k3s89w6y9090538j6aa7p4nmalf"))
                (modules '((guix build utils)))
                (snippet
                 '(begin
                    (substitute* "acinclude.m4"
                      ;; Do not embed build time
                      (("(DIST_ID=\"Custom build).*$" _ prefix)
                       (string-append prefix "\"\n"))
                      ;; Do not leak information about the build host
                      (("DIST_NAME=\"\\$build_os\"")
                       "DIST_NAME=\"guix\""))
                    #t))))
      (arguments
       (substitute-keyword-arguments (package-arguments icedtea-7)
         ((#:configure-flags flags)
          `(let ((jdk (assoc-ref %build-inputs "jdk")))
             `(;;"--disable-bootstrap"
               "--enable-bootstrap"
               "--enable-nss"
               "--disable-downloading"
               "--disable-system-pcsc"
               "--disable-system-sctp"
               "--disable-tests"      ;they are run in the check phase instead
               "--with-openjdk-src-dir=./openjdk.src"
               ,(string-append "--with-jdk-home=" jdk))))
         ((#:phases phases)
          `(modify-phases ,phases
             (delete 'fix-x11-extension-include-path)
             (delete 'patch-paths)
             (delete 'set-additional-paths)
             (delete 'patch-patches)
             (add-after 'unpack 'patch-jni-libs
               ;; Hardcode dynamically loaded libraries.
               (lambda _
                 (let* ((library-path (search-path-as-string->list
                                       (getenv "LIBRARY_PATH")))
                        (find-library (lambda (name)
                                        (search-path
                                         library-path
                                         (string-append "lib" name ".so")))))
                   (for-each
                    (lambda (file)
                      (catch 'decoding-error
                        (lambda ()
                          (substitute* file
                            (("VERSIONED_JNI_LIB_NAME\\(\"(.*)\", \"(.*)\"\\)"
                              _ name version)
                             (format #f "\"~a\""  (find-library name)))
                            (("JNI_LIB_NAME\\(\"(.*)\"\\)" _ name)
                             (format #f "\"~a\"" (find-library name)))))
                        (lambda _
                          ;; Those are safe to skip.
                          (format (current-error-port)
                                  "warning: failed to substitute: ~a~%"
                                  file))))
                    (find-files "openjdk.src/jdk/src/solaris/native"
                                "\\.c|\\.h"))
                   #t)))
             (replace 'install
               (lambda* (#:key outputs #:allow-other-keys)
                 (let ((doc (string-append (assoc-ref outputs "doc")
                                           "/share/doc/icedtea"))
                       (jre (assoc-ref outputs "out"))
                       (jdk (assoc-ref outputs "jdk")))
                   (copy-recursively "openjdk.build/docs" doc)
                   (copy-recursively "openjdk.build/images/j2re-image" jre)
                   (copy-recursively "openjdk.build/images/j2sdk-image" jdk)
                   ;; Install the nss.cfg file to JRE to enable SSL/TLS
                   ;; support via NSS.
                   (copy-file (string-append jdk "/jre/lib/security/nss.cfg")
                              (string-append jre "/lib/security/nss.cfg"))
                   #t)))))))
      (native-inputs
       `(("jdk" ,icedtea-7 "jdk")
         ("openjdk-src"
          ,(drop "openjdk"
                 "0a6yrq8y1zkzc7hm2l28rm3vzy5izfxhmmhhhvc91lhfclnqcd2q"))
         ("aarch32-drop"
          ,(drop "aarch32"
                 "0cway5a5hcfyh4pzl9zz5xr7lil4gsliy6r5iqbaasd2d9alvqiq"))
         ("corba-drop"
          ,(drop "corba"
                 "031sc6byd8lqvz3cd07phm13pqrxalxk9f3a2q8pim5n4sbsy0qb"))
         ("jaxp-drop"
          ,(drop "jaxp"
                 "1815jaj0k0w1s0g0jr1ahkajp1jx2qlb08i6l9ha4wyqqyp49a4n"))
         ("jaxws-drop"
          ,(drop "jaxws"
                 "0vh4f85cxhqvabzg86ycpz02519cdzgsn5dr75k22rkmbbxnbbl6"))
         ("jdk-drop"
          ,(drop "jdk"
                 "196ycqz4d9kknc6b219q4ib83l1kkl6w6l1cznw9bzaafyynqa35"))
         ("langtools-drop"
          ,(drop "langtools"
                 "0ssnadlr5cxhmj06nmni34kdynix1sjhcvjzahm5yzfd7dfllmgy"))
         ("hotspot-drop"
          ,(drop "hotspot"
                 "0f7fxf0s9kadvs80hm5ga72pyp9r0fvl8zm1wmd1wrks8kl79sd6"))
         ("nashorn-drop"
          ,(drop "nashorn"
                 "0m95qgnd4z6p0xp9m06ihss7skx2yrm7xw69jsjsrxpriy1shiwy"))
         ("shenandoah-drop"
          ,(drop "shenandoah"
                 "0yjlcgp6mldp30hmkfl68mdwlbg3gb0m6xd5y7srczni7cln5f3i"))
         ,@(fold alist-delete (package-native-inputs icedtea-7)
                 '("jdk" "openjdk-src" "corba-drop" "jaxp-drop" "jaxws-drop"
                   "jdk-drop" "langtools-drop" "hotspot-drop")))))))

(define-public icedtea icedtea-7)


(define-public ant/java8
  (package (inherit ant-bootstrap)
    (name "ant")
    (version "1.10.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/ant/source/apache-ant-"
                                  version "-src.tar.gz"))
              (sha256
               (base32
                "10p3dh77lkzzzcy32dk9azljixzadp46fggjfbvgkl8mmb8cxxv8"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  (for-each delete-file
                            (find-files "lib/optional" "\\.jar$"))
                  #t))))
    (arguments
     (substitute-keyword-arguments (package-arguments ant-bootstrap)
       ((#:phases phases)
        `(modify-phases ,phases
           (add-after 'unpack 'remove-scripts
             ;; Remove bat / cmd scripts for DOS as well as the antRun and runant
             ;; wrappers.
             (lambda _
               (for-each delete-file
                         (find-files "src/script"
                                     "(.*\\.(bat|cmd)|runant.*|antRun.*)"))
               #t))
           (replace 'build
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (setenv "JAVA_HOME" (assoc-ref inputs "jdk"))

               ;; Disable tests to avoid dependency on hamcrest-core, which needs
               ;; Ant to build.  This is necessary in addition to disabling the
               ;; "check" phase, because the dependency on "test-jar" would always
               ;; result in the tests to be run.
               (substitute* "build.xml"
                 (("depends=\"jars,test-jar\"") "depends=\"jars\""))
               (zero? (system* "bash" "bootstrap.sh"
                               (string-append "-Ddist.dir="
                                              (assoc-ref outputs "out"))))))))))
    (native-inputs
     `(("jdk" ,icedtea-8 "jdk")))))

;; The 1.9.x series is the last that can be built with GCJ.  The 1.10.x series
;; requires Java 8.
(define-public ant
  (package (inherit ant/java8)
    (version "1.9.9")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/ant/source/apache-ant-"
                                  version "-src.tar.gz"))
              (sha256
               (base32
                "1k28mka0m3isy9yr8gz84kz1f3f879rwaxrd44vdn9xbfwvwk86n"))))
    (native-inputs
     `(("jdk" ,icedtea-7 "jdk")))))

(define-public clojure
  (let* ((remove-archives '(begin
                             (for-each delete-file
                                       (find-files "." ".*\\.(jar|zip)"))
                             #t))
         (submodule (lambda (prefix version hash)
                      (origin
                        (method url-fetch)
                        (uri (string-append "https://github.com/clojure/"
                                            prefix version ".tar.gz"))
                        (sha256 (base32 hash))
                        (modules '((guix build utils)))
                        (snippet remove-archives)))))
    (package
      (name "clojure")
      (version "1.8.0")
      (source
       (origin
         (method url-fetch)
         (uri
          (string-append "http://repo1.maven.org/maven2/org/clojure/clojure/"
                         version "/clojure-" version ".zip"))
         (sha256
          (base32 "1nip095fz5c492sw15skril60i1vd21ibg6szin4jcvyy3xr6cym"))
         (modules '((guix build utils)))
         (snippet remove-archives)))
      (build-system ant-build-system)
      (arguments
       `(#:modules ((guix build ant-build-system)
                    (guix build utils)
                    (ice-9 ftw)
                    (ice-9 regex)
                    (srfi srfi-1)
                    (srfi srfi-26))
         #:test-target "test"
         #:phases
         (modify-phases %standard-phases
           (add-after 'unpack 'unpack-submodule-sources
             (lambda* (#:key inputs #:allow-other-keys)
               (for-each
                (lambda (name)
                  (mkdir-p name)
                  (with-directory-excursion name
                    (or (zero? (system* "tar"
                                        ;; Use xz for repacked tarball.
                                        "--xz"
                                        "--extract"
                                        "--verbose"
                                        "--file" (assoc-ref inputs name)
                                        "--strip-components=1"))
                        (error "failed to unpack tarball" name)))
                  (copy-recursively (string-append name "/src/main/clojure/")
                                    "src/clj/"))
                '("data-generators-src"
                  "java-classpath-src"
                  "test-check-src"
                  "test-generative-src"
                  "tools-namespace-src"
                  "tools-reader-src"))
               #t))
           ;; The javadoc target is not built by default.
           (add-after 'build 'build-doc
             (lambda _
               (zero? (system* "ant" "javadoc"))))
           ;; Needed since no install target is provided.
           (replace 'install
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((java-dir (string-append (assoc-ref outputs "out")
                                              "/share/java/")))
                 ;; Install versioned to avoid collisions.
                 (install-file (string-append "clojure-" ,version ".jar")
                               java-dir)
                 #t)))
           ;; Needed since no install-doc target is provided.
           (add-after 'install 'install-doc
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((doc-dir (string-append (assoc-ref outputs "out")
                                             "/share/doc/clojure-"
                                             ,version "/")))
                 (copy-recursively "doc/clojure" doc-dir)
                 (copy-recursively "target/javadoc/"
                                   (string-append doc-dir "javadoc/"))
                 (for-each (cut install-file <> doc-dir)
                           (filter (cut string-match
                                     ".*\\.(html|markdown|md|txt)"
                                     <>)
                                   (scandir "./")))
                 #t))))))
      ;; The native-inputs below are needed to run the tests.
      (native-inputs
       `(("data-generators-src"
          ,(submodule "data.generators/archive/data.generators-"
                      "0.1.2"
                      "0kki093jp4ckwxzfnw8ylflrfqs8b1i1wi9iapmwcsy328dmgzp1"))
         ("java-classpath-src"
          ,(submodule "java.classpath/archive/java.classpath-"
                      "0.2.3"
                      "0sjymly9xh1lkvwn5ygygpsfwz4dabblnlq0c9bx76rkvq62fyng"))
         ("test-check-src"
          ,(submodule "test.check/archive/test.check-"
                      "0.9.0"
                      "0p0mnyhr442bzkz0s4k5ra3i6l5lc7kp6ajaqkkyh4c2k5yck1md"))
         ("test-generative-src"
          ,(submodule "test.generative/archive/test.generative-"
                      "0.5.2"
                      "1pjafy1i7yblc7ixmcpfq1lfbyf3jaljvkgrajn70sws9xs7a9f8"))
         ("tools-namespace-src"
          ,(submodule "tools.namespace/archive/tools.namespace-"
                      "0.2.11"
                      "10baak8v0hnwz2hr33bavshm7y49mmn9zsyyms1dwjz45p5ymhy0"))
         ("tools-reader-src"
          ,(submodule "tools.reader/archive/tools.reader-"
                      "1.0.0"
                      "1lafblmmj4hkg0aqrf19qkdw9wdcsh3qxmn6cbkmnzbhffpyv2lv"))))
      (home-page "https://clojure.org/")
      (synopsis "Lisp dialect running on the JVM")
      (description "Clojure is a dynamic, general-purpose programming language,
combining the approachability and interactive development of a scripting
language with an efficient and robust infrastructure for multithreaded
programming.  Clojure is a compiled language, yet remains completely dynamic
– every feature supported by Clojure is supported at runtime.  Clojure
provides easy access to the Java frameworks, with optional type hints and type
inference, to ensure that calls to Java can avoid reflection.

Clojure is a dialect of Lisp, and shares with Lisp the code-as-data philosophy
and a powerful macro system.  Clojure is predominantly a functional programming
language, and features a rich set of immutable, persistent data structures.
When mutable state is needed, Clojure offers a software transactional memory
system and reactive Agent system that ensure clean, correct, multithreaded
designs.")
      ;; Clojure is licensed under EPL1.0
      ;; ASM bytecode manipulation library is licensed under BSD-3
      ;; Guava Murmur3 hash implementation is licensed under APL2.0
      ;; src/clj/repl.clj is licensed under CPL1.0
      ;;
      ;; See readme.html or readme.txt for details.
      (license (list license:epl1.0
                     license:bsd-3
                     license:asl2.0
                     license:cpl1.0)))))

(define-public java-classpathx-servletapi
  (package
    (name "java-classpathx-servletapi")
    (version "3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://gnu/classpathx/servletapi/"
                                  "servletapi-" version ".tar.gz"))
              (sha256
               (base32
                "0y9489pk4as9q6x300sk3ycc0psqfxcd4b0xvbmf3rhgli8q1kx3"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; there is no test target
       #:build-target "compile"
       ;; NOTE: This package does not build with Java 8 because of a type
       ;; mismatch in
       ;; "source/javax/servlet/jsp/el/ImplicitObjectELResolver.java".  It
       ;; defines the return value of ScopeMap's "remove" method to be of type
       ;; "Object", whereas Map's "remove" method returns boolean.
       #:make-flags
       (list "-Dbuild.compiler=javac1.7"
             (string-append "-Ddist=" (assoc-ref %outputs "out")))
       #:phases
       (modify-phases %standard-phases
         (replace 'install
           (lambda* (#:key make-flags #:allow-other-keys)
             (zero? (apply system* `("ant" "dist" ,@make-flags))))))))
    (home-page "https://www.gnu.org/software/classpathx/")
    (synopsis "Java servlet API implementation")
    (description "This is the GNU servlet API distribution, part of the
ClasspathX project.  It provides implementations of version 3.0 of the servlet
API and version 2.1 of the Java ServerPages API.")
    (license license:gpl3+)))

(define-public java-swt
  (package
    (name "java-swt")
    (version "4.6")
    (source
     ;; The types of many variables and procedures differ in the sources
     ;; dependent on whether the target architecture is a 32-bit system or a
     ;; 64-bit system.  Instead of patching the sources on demand in a build
     ;; phase we download either the 32-bit archive (which mostly uses "int"
     ;; types) or the 64-bit archive (which mostly uses "long" types).
     (let ((hash32 "0jmx1h65wqxsyjzs64i2z6ryiynllxzm13cq90fky2qrzagcw1ir")
           (hash64 "0wnd01xssdq9pgx5xqh5lfiy3dmk60dzzqdxzdzf883h13692lgy")
           (file32 "x86")
           (file64 "x86_64"))
       (let-values (((hash file)
                     (match (or (%current-target-system) (%current-system))
                       ("x86_64-linux" (values hash64 file64))
                       (_              (values hash32 file32)))))
         (origin
           (method url-fetch)
           (uri (string-append
                 "http://ftp-stud.fht-esslingen.de/pub/Mirrors/"
                 "eclipse/eclipse/downloads/drops4/R-" version
                 "-201606061100/swt-" version "-gtk-linux-" file ".zip"))
           (sha256 (base32 hash))))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "swt.jar"
       #:tests? #f ; no "check" target
       #:phases
       (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (and (mkdir "swt")
                  (zero? (system* "unzip" source "-d" "swt"))
                  (chdir "swt")
                  (mkdir "src")
                  (zero? (system* "unzip" "src.zip" "-d" "src")))))
         ;; The classpath contains invalid icecat jars.  Since we don't need
         ;; anything other than the JDK on the classpath, we can simply unset
         ;; it.
         (add-after 'configure 'unset-classpath
           (lambda _ (unsetenv "CLASSPATH") #t))
         (add-before 'build 'build-native
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((lib (string-append (assoc-ref outputs "out") "/lib")))
               ;; Build shared libraries.  Users of SWT have to set the system
               ;; property swt.library.path to the "lib" directory of this
               ;; package output.
               (mkdir-p lib)
               (setenv "OUTPUT_DIR" lib)
               (with-directory-excursion "src"
                 (zero? (system* "bash" "build.sh"))))))
         (add-after 'install 'install-native
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((lib (string-append (assoc-ref outputs "out") "/lib")))
               (for-each (lambda (file)
                           (install-file file lib))
                         (find-files "." "\\.so$"))
               #t))))))
    (inputs
     `(("xulrunner" ,icecat)
       ("gtk" ,gtk+-2)
       ("libxtst" ,libxtst)
       ("libxt" ,libxt)
       ("mesa" ,mesa)
       ("glu" ,glu)))
    (native-inputs
     `(("pkg-config" ,pkg-config)
       ("unzip" ,unzip)))
    (home-page "https://www.eclipse.org/swt/")
    (synopsis "Widget toolkit for Java")
    (description
     "SWT is a widget toolkit for Java designed to provide efficient, portable
access to the user-interface facilities of the operating systems on which it
is implemented.")
    ;; SWT code is licensed under EPL1.0
    ;; Gnome and Gtk+ bindings contain code licensed under LGPLv2.1
    ;; Cairo bindings contain code under MPL1.1
    ;; XULRunner 1.9 bindings contain code under MPL2.0
    (license (list
              license:epl1.0
              license:mpl1.1
              license:mpl2.0
              license:lgpl2.1+))))

(define-public java-xz
  (package
   (name "java-xz")
   (version "1.6")
   (source (origin
     (method url-fetch)
     (uri (string-append "http://tukaani.org/xz/xz-java-" version ".zip"))
     (sha256
      (base32
       "1z3p1ri1gvl07inxn0agx44ck8n7wrzfmvkz8nbq3njn8r9wba8x"))))
   (build-system ant-build-system)
   (arguments
    `(#:tests? #f ; There are no tests to run.
      #:jar-name ,(string-append "xz-" version  ".jar")
      #:phases
      (modify-phases %standard-phases
        ;; The unpack phase enters the "maven" directory by accident.
        (add-after 'unpack 'chdir
          (lambda _ (chdir "..") #t)))))
   (native-inputs
    `(("unzip" ,unzip)))
   (home-page "http://tukaani.org/xz/java.html")
   (synopsis "Implementation of XZ data compression in pure Java")
   (description "This library aims to be a complete implementation of XZ data
compression in pure Java.  Single-threaded streamed compression and
decompression and random access decompression have been fully implemented.")
   (license license:public-domain)))

;; java-hamcrest-core uses qdox version 1.12.  We package this version instead
;; of the latest release.
(define-public java-qdox-1.12
  (package
    (name "java-qdox")
    (version "1.12.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/"
                                  "com/thoughtworks/qdox/qdox/" version
                                  "/qdox-" version "-sources.jar"))
              (sha256
               (base32
                "0hlfbqq2avf5s26wxkksqmkdyk6zp9ggqn37c468m96mjv0n9xfl"))))
    (build-system ant-build-system)
    (arguments
     `(;; Tests require junit
       #:tests? #f
       #:jar-name "qdox.jar"
       #:phases
       (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source #:allow-other-keys)
             (mkdir "src")
             (with-directory-excursion "src"
               (zero? (system* "jar" "-xf" source)))))
         ;; At this point we don't have junit, so we must remove the API
         ;; tests.
         (add-after 'unpack 'delete-tests
           (lambda _
             (delete-file-recursively "src/com/thoughtworks/qdox/junit")
             #t)))))
    (home-page "http://qdox.codehaus.org/")
    (synopsis "Parse definitions from Java source files")
    (description
     "QDox is a high speed, small footprint parser for extracting
class/interface/method definitions from source files complete with JavaDoc
@code{@@tags}.  It is designed to be used by active code generators or
documentation tools.")
    (license license:asl2.0)))

(define-public java-jarjar
  (package
    (name "java-jarjar")
    (version "1.4")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://storage.googleapis.com/google-code-archive-downloads/v2/"
                    "code.google.com/jarjar/jarjar-src-" version ".zip"))
              (sha256
               (base32
                "1v8irhni9cndcw1l1wxqgry013s2kpj0qqn57lj2ji28xjq8ndjl"))))
    (build-system ant-build-system)
    (arguments
     `(;; Tests require junit, which ultimately depends on this package.
       #:tests? #f
       #:build-target "jar"
       #:phases
       (modify-phases %standard-phases
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((target (string-append (assoc-ref outputs "out")
                                          "/share/java")))
               (install-file (string-append "dist/jarjar-" ,version ".jar")
                             target))
             #t)))))
    (native-inputs
     `(("unzip" ,unzip)))
    (home-page "https://code.google.com/archive/p/jarjar/")
    (synopsis "Repackage Java libraries")
    (description
     "Jar Jar Links is a utility that makes it easy to repackage Java
libraries and embed them into your own distribution.  Jar Jar Links includes
an Ant task that extends the built-in @code{jar} task.")
    (license license:asl2.0)))

(define-public java-hamcrest-core
  (package
    (name "java-hamcrest-core")
    (version "1.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/hamcrest/JavaHamcrest/"
                                  "archive/hamcrest-java-" version ".tar.gz"))
              (sha256
               (base32
                "11g0s105fmwzijbv08lx8jlb521yravjmxnpgdx08fvg1kjivhva"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  ;; Delete bundled thirds-party jar archives.
                  (delete-file-recursively "lib")
                  #t))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; Tests require junit
       #:modules ((guix build ant-build-system)
                  (guix build utils)
                  (srfi srfi-1))
       #:make-flags (list (string-append "-Dversion=" ,version))
       #:test-target "unit-test"
       #:build-target "core"
       #:phases
       (modify-phases %standard-phases
         ;; Disable unit tests, because they require junit, which requires
         ;; hamcrest-core.  We also give a fixed value to the "Built-Date"
         ;; attribute from the manifest for reproducibility.
         (add-before 'configure 'patch-build.xml
           (lambda _
             (substitute* "build.xml"
               (("unit-test, ") "")
               (("\\$\\{build.timestamp\\}") "guix"))
             #t))
         ;; Java's "getMethods()" returns methods in an unpredictable order.
         ;; To make the output of the generated code deterministic we must
         ;; sort the array of methods.
         (add-after 'unpack 'make-method-order-deterministic
           (lambda _
             (substitute* "hamcrest-generator/src/main/java/org/hamcrest/generator/ReflectiveFactoryReader.java"
               (("import java\\.util\\.Iterator;" line)
                (string-append line "\n"
                               "import java.util.Arrays; import java.util.Comparator;"))
               (("allMethods = cls\\.getMethods\\(\\);" line)
                (string-append "_" line
                               "
private Method[] getSortedMethods() {
  Arrays.sort(_allMethods, new Comparator<Method>() {
    @Override
    public int compare(Method a, Method b) {
      return a.toString().compareTo(b.toString());
    }
  });
  return _allMethods;
}

private Method[] allMethods = getSortedMethods();")))))
         (add-before 'build 'do-not-use-bundled-qdox
           (lambda* (#:key inputs #:allow-other-keys)
             (substitute* "build.xml"
               (("lib/generator/qdox-1.12.jar")
                (string-append (assoc-ref inputs "java-qdox-1.12")
                               "/share/java/qdox.jar")))
             #t))
         ;; build.xml searches for .jar files in this directoy, which
         ;; we remove  from the source archive.
         (add-before 'build 'create-dummy-directories
           (lambda _
             (mkdir-p "lib/integration")
             #t))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((target (string-append (assoc-ref outputs "out")
                                           "/share/java/"))
                    (version-suffix ,(string-append "-" version ".jar"))
                    (install-without-version-suffix
                     (lambda (jar)
                       (copy-file jar
                                  (string-append target
                                                 (basename jar version-suffix)
                                                 ".jar")))))
               (mkdir-p target)
               (for-each
                install-without-version-suffix
                (find-files "build"
                            (lambda (name _)
                              (and (string-suffix? ".jar" name)
                                   (not (string-suffix? "-sources.jar" name)))))))
             #t)))))
    (native-inputs
     `(("java-qdox-1.12" ,java-qdox-1.12)
       ("java-jarjar" ,java-jarjar)))
    (home-page "http://hamcrest.org/")
    (synopsis "Library of matchers for building test expressions")
    (description
     "This package provides a library of matcher objects (also known as
constraints or predicates) allowing @code{match} rules to be defined
declaratively, to be used in other frameworks.  Typical scenarios include
testing frameworks, mocking libraries and UI validation rules.")
    (license license:bsd-2)))

(define-public java-junit
  (package
    (name "java-junit")
    (version "4.12")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/junit-team/junit/"
                                  "archive/r" version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "090dn5v1vs0b3acyaqc0gjf6p8lmd2h24wfzsbq7sly6b214anws"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  ;; Delete bundled jar archives.
                  (delete-file-recursively "lib")
                  #t))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests
       #:jar-name "junit.jar"))
    (inputs
     `(("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://junit.org/")
    (synopsis "Test framework for Java")
    (description
     "JUnit is a simple framework to write repeatable tests for Java projects.
JUnit provides assertions for testing expected results, test fixtures for
sharing common test data, and test runners for running tests.")
    (license license:epl1.0)))

(define-public java-plexus-utils
  (package
    (name "java-plexus-utils")
    (version "3.0.24")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/codehaus-plexus/"
                                  "plexus-utils/archive/plexus-utils-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "1mlwpc6fms24slygv5yvi6fi9hcha2fh0v73p5znpi78bg36i2js"))))
    (build-system ant-build-system)
    ;; FIXME: The default build.xml does not include a target to install
    ;; javadoc files.
    (arguments
     `(#:jar-name "plexus-utils.jar"
       #:source-dir "src/main"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'fix-reference-to-/bin-and-/usr
           (lambda _
             (substitute* "src/main/java/org/codehaus/plexus/util/\
cli/shell/BourneShell.java"
               (("/bin/sh") (which "sh"))
               (("/usr/")   (getcwd)))
             #t))
         (add-after 'unpack 'fix-or-disable-broken-tests
           (lambda _
             (with-directory-excursion "src/test/java/org/codehaus/plexus/util"
               (substitute* '("cli/CommandlineTest.java"
                              "cli/shell/BourneShellTest.java")
                 (("/bin/sh")   (which "sh"))
                 (("/bin/echo") (which "echo")))

               ;; This test depends on MavenProjectStub, but we don't have
               ;; a package for Maven.
               (delete-file "introspection/ReflectionValueExtractorTest.java")

               ;; FIXME: The command line tests fail, maybe because they use
               ;; absolute paths.
               (delete-file "cli/CommandlineTest.java"))
             #t)))))
    (native-inputs
     `(("java-junit" ,java-junit)))
    (home-page "http://codehaus-plexus.github.io/plexus-utils/")
    (synopsis "Common utilities for the Plexus framework")
    (description "This package provides various Java utility classes for the
Plexus framework to ease working with strings, files, command lines, XML and
more.")
    (license license:asl2.0)))

(define-public java-plexus-interpolation
  (package
    (name "java-plexus-interpolation")
    (version "1.23")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/codehaus-plexus/"
                                  "plexus-interpolation/archive/"
                                  "plexus-interpolation-" version ".tar.gz"))
              (sha256
               (base32
                "1w79ljwk42ymrgy8kqxq4l82pgdj6287gabpfnpkyzbrnclsnfrp"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "plexus-interpolation.jar"
       #:source-dir "src/main"))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://codehaus-plexus.github.io/plexus-interpolation/")
    (synopsis "Java components for interpolating ${} strings and the like")
    (description "Plexus interpolator is a modular, flexible interpolation
framework for the expression language style commonly seen in Maven, Plexus,
and other related projects.

It has its foundation in the @code{org.codehaus.plexus.utils.interpolation}
package within @code{plexus-utils}, but has been separated in order to allow
these two libraries to vary independently of one another.")
    (license license:asl2.0)))

(define-public java-asm
  (package
    (name "java-asm")
    (version "5.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://download.forge.ow2.org/asm/"
                                  "asm-" version ".tar.gz"))
              (sha256
               (base32
                "0kxvmv5275rnjl7jv0442k3wjnq03ngkb7sghs78avf45pzm4qgr"))))
    (build-system ant-build-system)
    (arguments
     `(#:build-target "compile"
       ;; The tests require an old version of Janino, which no longer compiles
       ;; with the JDK7.
       #:tests? #f
       ;; We don't need these extra ant tasks, but the build system asks us to
       ;; provide a path anyway.
       #:make-flags (list (string-append "-Dobjectweb.ant.tasks.path=foo"))
       #:phases
       (modify-phases %standard-phases
         (add-before 'install 'build-jars
           (lambda* (#:key make-flags #:allow-other-keys)
             ;; We cannot use the "jar" target because it depends on a couple
             ;; of unpackaged, complicated tools.
             (mkdir "dist")
             (zero? (system* "jar"
                             "-cf" (string-append "dist/asm-" ,version ".jar")
                             "-C" "output/build/tmp" "."))))
         (replace 'install
           (install-jars "dist")))))
    (native-inputs
     `(("java-junit" ,java-junit)))
    (home-page "http://asm.ow2.org/")
    (synopsis "Very small and fast Java bytecode manipulation framework")
    (description "ASM is an all purpose Java bytecode manipulation and
analysis framework.  It can be used to modify existing classes or dynamically
generate classes, directly in binary form.  The provided common
transformations and analysis algorithms allow to easily assemble custom
complex transformations and code analysis tools.")
    (license license:bsd-3)))

(define-public java-cglib
  (package
    (name "java-cglib")
    (version "3.2.4")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/cglib/cglib/archive/RELEASE_"
                    (string-map (lambda (c) (if (char=? c #\.) #\_ c)) version)
                    ".tar.gz"))
              (file-name (string-append "cglib-" version ".tar.gz"))
              (sha256
               (base32
                "162dvd4fln76ai8prfharf66pn6r56p3sxx683j5vdyccrd5hi1q"))))
    (build-system ant-build-system)
    (arguments
     `(;; FIXME: tests fail because junit runs
       ;; "net.sf.cglib.transform.AbstractTransformTest", which does not seem
       ;; to describe a test at all.
       #:tests? #f
       #:jar-name "cglib.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'chdir
           (lambda _ (chdir "cglib") #t)))))
    (inputs
     `(("java-asm" ,java-asm)
       ("java-junit" ,java-junit)))
    (home-page "https://github.com/cglib/cglib/")
    (synopsis "Java byte code generation library")
    (description "The byte code generation library CGLIB is a high level API
to generate and transform Java byte code.")
    (license license:asl2.0)))

(define-public java-objenesis
  (package
    (name "java-objenesis")
    (version "2.5.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/easymock/objenesis/"
                                  "archive/" version ".tar.gz"))
              (file-name (string-append "objenesis-" version ".tar.gz"))
              (sha256
               (base32
                "1va5qz1i2wawwavhnxfzxnfgrcaflz9p1pg03irrjh4nd3rz8wh6"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "objenesis.jar"
       #:source-dir "main/src/"
       #:test-dir "main/src/test/"))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://objenesis.org/")
    (synopsis "Bypass the constructor when creating an object")
    (description "Objenesis is a small Java library that serves one purpose:
to instantiate a new object of a particular class.  It is common to see
restrictions in libraries stating that classes must require a default
constructor.  Objenesis aims to overcome these restrictions by bypassing the
constructor on object instantiation.")
    (license license:asl2.0)))

(define-public java-easymock
  (package
    (name "java-easymock")
    (version "3.4")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/easymock/easymock/"
                                  "archive/easymock-" version ".tar.gz"))
              (sha256
               (base32
                "1yzg0kv256ndr57gpav46cyv4a1ns5sj722l50zpxk3j6sk9hnmi"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "easymock.jar"
       #:source-dir "core/src/main"
       #:test-dir "core/src/test"
       #:phases
       (modify-phases %standard-phases
         ;; FIXME: Android support requires the following packages to be
         ;; available: com.google.dexmaker.stock.ProxyBuilder
         (add-after 'unpack 'delete-android-support
           (lambda _
             (with-directory-excursion "core/src/main/java/org/easymock/internal"
               (substitute* "MocksControl.java"
                 (("AndroidSupport.isAndroid\\(\\)") "false")
                 (("return classProxyFactory = new AndroidClassProxyFactory\\(\\);") ""))
               (delete-file "AndroidClassProxyFactory.java"))
             #t))
         (add-after 'unpack 'delete-broken-tests
           (lambda _
             (with-directory-excursion "core/src/test/java/org/easymock"
               ;; This test depends on dexmaker.
               (delete-file "tests2/ClassExtensionHelperTest.java")

               ;; This is not a test.
               (delete-file "tests/BaseEasyMockRunnerTest.java")

               ;; This test should be executed with a different runner...
               (delete-file "tests2/EasyMockAnnotationsTest.java")
               ;; ...but deleting it means that we also have to delete these
               ;; dependent files.
               (delete-file "tests2/EasyMockRunnerTest.java")
               (delete-file "tests2/EasyMockRuleTest.java")

               ;; This test fails because the file "easymock.properties" does
               ;; not exist.
               (delete-file "tests2/EasyMockPropertiesTest.java"))
             #t)))))
    (inputs
     `(("java-asm" ,java-asm)
       ("java-cglib" ,java-cglib)
       ("java-objenesis" ,java-objenesis)))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://easymock.org")
    (synopsis "Java library providing mock objects for unit tests")
    (description "EasyMock is a Java library that provides an easy way to use
mock objects in unit testing.")
    (license license:asl2.0)))

(define-public java-jmock-1
  (package
    (name "java-jmock")
    (version "1.2.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/jmock-developers/"
                                  "jmock-library/archive/" version ".tar.gz"))
              (file-name (string-append "jmock-" version ".tar.gz"))
              (sha256
               (base32
                "0xmrlhq0fszldkbv281k9463mv496143vvmqwpxp62yzjvdkx9w0"))))
    (build-system ant-build-system)
    (arguments
     `(#:build-target "jars"
       #:test-target "run.tests"
       #:phases
       (modify-phases %standard-phases
         (replace 'install (install-jars "build")))))
    (home-page "http://www.jmock.org")
    (synopsis "Mock object library for test-driven development")
    (description "JMock is a library that supports test-driven development of
Java code with mock objects.  Mock objects help you design and test the
interactions between the objects in your programs.

The jMock library

@itemize
@item makes it quick and easy to define mock objects
@item lets you precisely specify the interactions between
  your objects, reducing the brittleness of your tests
@item plugs into your favourite test framework
@item is easy to extend.
@end itemize\n")
    (license license:bsd-3)))

(define-public java-hamcrest-all
  (package (inherit java-hamcrest-core)
    (name "java-hamcrest-all")
    (arguments
     (substitute-keyword-arguments (package-arguments java-hamcrest-core)
       ;; FIXME: a unit test fails because org.hamcrest.SelfDescribing is not
       ;; found, although it is part of the hamcrest-core library that has
       ;; just been built.
       ;;
       ;; Fixing this one test is insufficient, though, and upstream confirmed
       ;; that the latest hamcrest release fails its unit tests when built
       ;; with Java 7.  See https://github.com/hamcrest/JavaHamcrest/issues/30
       ((#:tests? _) #f)
       ((#:build-target _) "bigjar")
       ((#:phases phases)
        `(modify-phases ,phases
           ;; Some build targets override the classpath, so we need to patch
           ;; the build.xml to ensure that required dependencies are on the
           ;; classpath.
           (add-after 'unpack 'patch-classpath-for-integration
             (lambda* (#:key inputs #:allow-other-keys)
               (substitute* "build.xml"
                 ((" build/hamcrest-library-\\$\\{version\\}.jar" line)
                  (string-join
                   (cons line
                         (append
                          (find-files (assoc-ref inputs "java-hamcrest-core") "\\.jar$")
                          (find-files (assoc-ref inputs "java-junit") "\\.jar$")
                          (find-files (assoc-ref inputs "java-jmock") "\\.jar$")
                          (find-files (assoc-ref inputs "java-easymock") "\\.jar$")))
                   ";")))
               #t))))))
    (inputs
     `(("java-junit" ,java-junit)
       ("java-jmock" ,java-jmock-1)
       ("java-easymock" ,java-easymock)
       ("java-hamcrest-core" ,java-hamcrest-core)
       ,@(package-inputs java-hamcrest-core)))))

(define-public java-jopt-simple
  (package
    (name "java-jopt-simple")
    (version "5.0.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://repo1.maven.org/maven2/"
                                  "net/sf/jopt-simple/jopt-simple/"
                                  version "/jopt-simple-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1v8bzmwmw6qq20gm42xyay6vrd567dra4vqwhgjnqqjz1gs9f8qa"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; there are no tests
       #:jar-name "jopt-simple.jar"))
    (home-page "https://pholser.github.io/jopt-simple/")
    (synopsis "Java library for parsing command line options")
    (description "JOpt Simple is a Java library for parsing command line
options, such as those you might pass to an invocation of @code{javac}.  In
the interest of striving for simplicity, as closely as possible JOpt Simple
attempts to honor the command line option syntaxes of POSIX @code{getopt} and
GNU @code{getopt_long}.  It also aims to make option parser configuration and
retrieval of options and their arguments simple and expressive, without being
overly clever.")
    (license license:expat)))

(define-public java-commons-math3
  (package
    (name "java-commons-math3")
    (version "3.6.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/math/source/"
                                  "commons-math3-" version "-src.tar.gz"))
              (sha256
               (base32
                "19l6yp44qc5g7wg816nbn5z3zq3xxzwimvbm4a8pczgvpi4i85s6"))))
    (build-system ant-build-system)
    (arguments
     `(#:build-target "jar"
       #:test-target "test"
       #:make-flags
       (let ((hamcrest (assoc-ref %build-inputs "java-hamcrest-core"))
             (junit    (assoc-ref %build-inputs "java-junit")))
         (list (string-append "-Djunit.jar=" junit "/share/java/junit.jar")
               (string-append "-Dhamcrest.jar=" hamcrest
                              "/share/java/hamcrest-core.jar")))
       #:phases
       (modify-phases %standard-phases
         ;; We want to build the jar in the build phase and run the tests
         ;; later in a separate phase.
         (add-after 'unpack 'untangle-targets
           (lambda _
             (substitute* "build.xml"
               (("name=\"jar\" depends=\"test\"")
                "name=\"jar\" depends=\"compile\""))
             #t))
         ;; There is no install target.
         (replace 'install
           (install-jars "target")))))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://commons.apache.org/math/")
    (synopsis "Apache Commons mathematics library")
    (description "Commons Math is a library of lightweight, self-contained
mathematics and statistics components addressing the most common problems not
available in the Java programming language or Commons Lang.")
    (license license:asl2.0)))

(define-public java-jmh
  (package
    (name "java-jmh")
    (version "1.17.5")
    (source (origin
              (method hg-fetch)
              (uri (hg-reference
                    (url "http://hg.openjdk.java.net/code-tools/jmh/")
                    (changeset version)))
              (file-name (string-append name "-" version "-checkout"))
              (sha256
               (base32
                "1fxyxhg9famwcg1prc4cgwb5wzyxqavn3cjm5vz8605xz7x5k084"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "jmh-core.jar"
       #:source-dir "jmh-core/src/main"
       #:test-dir "jmh-core/src/test"
       #:phases
       (modify-phases %standard-phases
         ;; This seems to be a bug in the JDK.  It may not be necessary in
         ;; future versions of the JDK.
         (add-after 'unpack 'fix-bug
           (lambda _
             (with-directory-excursion
                 "jmh-core/src/main/java/org/openjdk/jmh/runner/options"
               (substitute* '("IntegerValueConverter.java"
                              "ThreadsValueConverter.java")
                 (("public Class<Integer> valueType")
                  "public Class<? extends Integer> valueType")))
             #t)))))
    (inputs
     `(("java-jopt-simple" ,java-jopt-simple)
       ("java-commons-math3" ,java-commons-math3)))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://openjdk.java.net/projects/code-tools/jmh/")
    (synopsis "Benchmark harness for the JVM")
    (description "JMH is a Java harness for building, running, and analysing
nano/micro/milli/macro benchmarks written in Java and other languages
targetting the JVM.")
    ;; GPLv2 only
    (license license:gpl2)))

(define-public java-commons-collections4
  (package
    (name "java-commons-collections4")
    (version "4.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/collections/source/"
                                  "commons-collections4-" version "-src.tar.gz"))
              (sha256
               (base32
                "1krfhvggympq4avk7gh6qafzf6b9ip6r1m4lmacikyx04039m0wl"))))
    (build-system ant-build-system)
    (arguments
     `(#:test-target "test"
       #:make-flags
       (let ((hamcrest (assoc-ref %build-inputs "java-hamcrest-core"))
             (junit    (assoc-ref %build-inputs "java-junit"))
             (easymock (assoc-ref %build-inputs "java-easymock")))
         (list (string-append "-Djunit.jar=" junit "/share/java/junit.jar")
               (string-append "-Dhamcrest.jar=" hamcrest
                              "/share/java/hamcrest-core.jar")
               (string-append "-Deasymock.jar=" easymock
                              "/share/java/easymock.jar")))
       #:phases
       (modify-phases %standard-phases
         (replace 'install
           (install-jars "target")))))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)
       ("java-easymock" ,java-easymock)))
    (home-page "http://commons.apache.org/collections/")
    (synopsis "Collections framework")
    (description "The Java Collections Framework is the recognised standard
for collection handling in Java.  Commons-Collections seek to build upon the
JDK classes by providing new interfaces, implementations and utilities.  There
are many features, including:

@itemize
@item @code{Bag} interface for collections that have a number of copies of
  each object
@item @code{BidiMap} interface for maps that can be looked up from value to
  key as well and key to value
@item @code{MapIterator} interface to provide simple and quick iteration over
  maps
@item Transforming decorators that alter each object as it is added to the
  collection
@item Composite collections that make multiple collections look like one
@item Ordered maps and sets that retain the order elements are added in,
  including an LRU based map
@item Reference map that allows keys and/or values to be garbage collected
  under close control
@item Many comparator implementations
@item Many iterator implementations
@item Adapter classes from array and enumerations to collections
@item Utilities to test or create typical set-theory properties of collections
  such as union, intersection, and closure.
@end itemize\n")
    (license license:asl2.0)))

(define-public java-commons-io
  (package
    (name "java-commons-io")
    (version "2.5")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://apache/commons/io/source/"
                           "commons-io-" version "-src.tar.gz"))
       (sha256
        (base32
         "0q5y41jrcjvx9hzs47x5kdhnasdy6rm4bzqd2jxl02w717m7a7v3"))))
    (build-system ant-build-system)
    (outputs '("out" "doc"))
    (arguments
     `(#:test-target "test"
       #:make-flags
       (list (string-append "-Djunit.jar="
                            (assoc-ref %build-inputs "java-junit")
                            "/share/java/junit.jar"))
       #:phases
       (modify-phases %standard-phases
         (add-after 'build 'build-javadoc ant-build-javadoc)
         (replace 'install (install-jars "target"))
         (add-after 'install 'install-doc (install-javadoc "target/apidocs")))))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://commons.apache.org/io/")
    (synopsis "Common useful IO related classes")
    (description "Commons-IO contains utility classes, stream implementations,
file filters and endian classes.")
    (license license:asl2.0)))

(define-public java-commons-lang
  (package
    (name "java-commons-lang")
    (version "2.6")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://apache/commons/lang/source/"
                           "commons-lang-" version "-src.tar.gz"))
       (sha256
        (base32 "1mxwagqadzx1b2al7i0z1v0r235aj2njdyijf02szq0vhmqrfiq5"))))
    (build-system ant-build-system)
    (outputs '("out" "doc"))
    (arguments
     `(#:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-after 'build 'build-javadoc ant-build-javadoc)
         (add-before 'check 'disable-failing-test
           (lambda _
             ;; Disable a failing test
             (substitute* "src/test/java/org/apache/commons/lang/\
time/FastDateFormatTest.java"
               (("public void testFormat\\(\\)")
                "public void disabled_testFormat()"))
             #t))
         (replace 'install (install-jars "target"))
         (add-after 'install 'install-doc (install-javadoc "target/apidocs")))))
    (native-inputs
     `(("java-junit" ,java-junit)))
    (home-page "http://commons.apache.org/lang/")
    (synopsis "Extension of the java.lang package")
    (description "The Commons Lang components contains a set of Java classes
that provide helper methods for standard Java classes, especially those found
in the @code{java.lang} package in the Sun JDK.  The following classes are
included:

@itemize
@item StringUtils - Helper for @code{java.lang.String}.
@item CharSetUtils - Methods for dealing with @code{CharSets}, which are sets
  of characters such as @code{[a-z]} and @code{[abcdez]}.
@item RandomStringUtils - Helper for creating randomised strings.
@item NumberUtils - Helper for @code{java.lang.Number} and its subclasses.
@item NumberRange - A range of numbers with an upper and lower bound.
@item ObjectUtils - Helper for @code{java.lang.Object}.
@item SerializationUtils - Helper for serializing objects.
@item SystemUtils - Utility class defining the Java system properties.
@item NestedException package - A sub-package for the creation of nested
  exceptions.
@item Enum package - A sub-package for the creation of enumerated types.
@item Builder package - A sub-package for the creation of @code{equals},
  @code{hashCode}, @code{compareTo} and @code{toString} methods.
@end itemize\n")
    (license license:asl2.0)))

(define-public java-commons-lang3
  (package
    (name "java-commons-lang3")
    (version "3.4")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "mirror://apache/commons/lang/source/"
                           "commons-lang3-" version "-src.tar.gz"))
       (sha256
        (base32 "0xpshb9spjhplq5a7mr0y1bgfw8190ik4xj8f569xidfcki1d6kg"))))
    (build-system ant-build-system)
    (outputs '("out" "doc"))
    (arguments
     `(#:test-target "test"
       #:make-flags
       (let ((hamcrest (assoc-ref %build-inputs "java-hamcrest-all"))
             (junit    (assoc-ref %build-inputs "java-junit"))
             (easymock (assoc-ref %build-inputs "java-easymock"))
             (io       (assoc-ref %build-inputs "java-commons-io")))
         (list (string-append "-Djunit.jar=" junit "/share/java/junit.jar")
               (string-append "-Dhamcrest.jar=" hamcrest
                              "/share/java/hamcrest-all.jar")
               (string-append "-Dcommons-io.jar=" io
                              "/share/java/commons-io-"
                              ,(package-version java-commons-io)
                              "-SNAPSHOT.jar")
               (string-append "-Deasymock.jar=" easymock
                              "/share/java/easymock.jar")))
       #:phases
       (modify-phases %standard-phases
         (add-after 'build 'build-javadoc ant-build-javadoc)
         (replace 'install (install-jars "target"))
         (add-after 'install 'install-doc (install-javadoc "target/apidocs")))))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-commons-io" ,java-commons-io)
       ("java-hamcrest-all" ,java-hamcrest-all)
       ("java-easymock" ,java-easymock)))
    (home-page "http://commons.apache.org/lang/")
    (synopsis "Extension of the java.lang package")
    (description "The Commons Lang components contains a set of Java classes
that provide helper methods for standard Java classes, especially those found
in the @code{java.lang} package.  The following classes are included:

@itemize
@item StringUtils - Helper for @code{java.lang.String}.
@item CharSetUtils - Methods for dealing with @code{CharSets}, which are sets of
  characters such as @code{[a-z]} and @code{[abcdez]}.
@item RandomStringUtils - Helper for creating randomised strings.
@item NumberUtils - Helper for @code{java.lang.Number} and its subclasses.
@item NumberRange - A range of numbers with an upper and lower bound.
@item ObjectUtils - Helper for @code{java.lang.Object}.
@item SerializationUtils - Helper for serializing objects.
@item SystemUtils - Utility class defining the Java system properties.
@item NestedException package - A sub-package for the creation of nested
   exceptions.
@item Enum package - A sub-package for the creation of enumerated types.
@item Builder package - A sub-package for the creation of @code{equals},
  @code{hashCode}, @code{compareTo} and @code{toString} methods.
@end itemize\n")
    (license license:asl2.0)))

(define-public java-jsr305
  (package
    (name "java-jsr305")
    (version "3.0.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "com/google/code/findbugs/"
                                  "jsr305/" version "/jsr305-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1rh6jin9v7jqpq3kf1swl868l8i94r636n03pzpsmgr8v0lh9j2n"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "jsr305.jar"))
    (home-page "http://findbugs.sourceforge.net/")
    (synopsis "Annotations for the static analyzer called findbugs")
    (description "This package provides annotations for the findbugs package.
It provides packages in the @code{javax.annotations} namespace.")
    (license license:asl2.0)))

(define-public java-guava
  (package
    (name "java-guava")
    ;; This is the last release of Guava that can be built with Java 7.
    (version "20.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/google/guava/"
                                  "releases/download/v" version
                                  "/guava-" version "-sources.jar"))
              (sha256
               (base32
                "1gawrs5gi6j5hcfxdgpnfli75vb9pfi4sn09pnc8xacr669yajwr"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f                      ; no tests included
       #:jar-name "guava.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'trim-sources
           (lambda _
             (with-directory-excursion "src/com/google/common"
               ;; Remove annotations to avoid extra dependencies:
               ;; * "j2objc" annotations are used when converting Java to
               ;;   Objective C;
               ;; * "errorprone" annotations catch common Java mistakes at
               ;;   compile time;
               ;; * "IgnoreJRERequirement" is used for Android.
               (substitute* (find-files "." "\\.java$")
                 (("import com.google.j2objc.*") "")
                 (("import com.google.errorprone.annotation.*") "")
                 (("import org.codehaus.mojo.animal_sniffer.*") "")
                 (("@CanIgnoreReturnValue") "")
                 (("@LazyInit") "")
                 (("@WeakOuter") "")
                 (("@RetainedWith") "")
                 (("@Weak") "")
                 (("@ForOverride") "")
                 (("@J2ObjCIncompatible") "")
                 (("@IgnoreJRERequirement") "")))
             #t)))))
    (inputs
     `(("java-jsr305" ,java-jsr305)))
    (home-page "https://github.com/google/guava")
    (synopsis "Google core libraries for Java")
    (description "Guava is a set of core libraries that includes new
collection types (such as multimap and multiset), immutable collections, a
graph library, functional types, an in-memory cache, and APIs/utilities for
concurrency, I/O, hashing, primitives, reflection, string processing, and much
more!")
    (license license:asl2.0)))

;; The java-commons-logging package provides adapters to many different
;; logging frameworks.  To avoid an excessive dependency graph we try to build
;; it with only a minimal set of adapters.
(define-public java-commons-logging-minimal
  (package
    (name "java-commons-logging-minimal")
    (version "1.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/logging/source/"
                                  "commons-logging-" version "-src.tar.gz"))
              (sha256
               (base32
                "10bwcy5w8d7y39n0krlwhnp8ds3kj5zhmzj0zxnkw0qdlsjmsrj9"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; avoid dependency on logging frameworks
       #:jar-name "commons-logging-minimal.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'delete-adapters-and-tests
           (lambda _
             ;; Delete all adapters except for NoOpLog, SimpleLog, and
             ;; LogFactoryImpl.  NoOpLog is required to build; LogFactoryImpl
             ;; is used by applications; SimpleLog is the only actually usable
             ;; implementation that does not depend on another logging
             ;; framework.
             (for-each
              (lambda (file)
                (delete-file (string-append
                              "src/main/java/org/apache/commons/logging/impl/" file)))
              (list "Jdk13LumberjackLogger.java"
                    "WeakHashtable.java"
                    "Log4JLogger.java"
                    "ServletContextCleaner.java"
                    "Jdk14Logger.java"
                    "AvalonLogger.java"
                    "LogKitLogger.java"))
             (delete-file-recursively "src/test")
             #t)))))
    (home-page "http://commons.apache.org/logging/")
    (synopsis "Common API for logging implementations")
    (description "The Logging package is a thin bridge between different
logging implementations.  A library that uses the commons-logging API can be
used with any logging implementation at runtime.")
    (license license:asl2.0)))

;; This is the last release of the 1.x series.
(define-public java-mockito-1
  (package
    (name "java-mockito")
    (version "1.10.19")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://repo1.maven.org/maven2/"
                                  "org/mockito/mockito-core/" version
                                  "/mockito-core-" version "-sources.jar"))
              (sha256
               (base32
                "0vmiwnwpf83g2q7kj1rislmja8fpvqkixjhawh7nxnygx6pq11kc"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "mockito.jar"
       #:tests? #f ; no tests included
       ;; FIXME: patch-and-repack does not support jars, so we have to apply
       ;; patches in build phases.
       #:phases
       (modify-phases %standard-phases
         ;; Mockito was developed against a different version of hamcrest,
         ;; which does not require matcher implementations to provide an
         ;; implementation of the "describeMismatch" method.  We add this
         ;; simple definition to pass the build with our version of hamcrest.
         (add-after 'unpack 'fix-hamcrest-build-error
           (lambda _
             (substitute* "src/org/mockito/internal/matchers/LocalizedMatcher.java"
               (("public Matcher getActualMatcher\\(\\) .*" line)
                (string-append "
    public void describeMismatch(Object item, Description description) {
        actualMatcher.describeMismatch(item, description);
    }"
                               line)))
             #t))
         ;; Mockito bundles cglib.  We have a cglib package, so let's use
         ;; that instead.
         (add-after 'unpack 'use-system-libraries
           (lambda _
             (with-directory-excursion "src/org/mockito/internal/creation/cglib"
               (substitute* '("CGLIBHacker.java"
                              "CglibMockMaker.java"
                              "ClassImposterizer.java"
                              "DelegatingMockitoMethodProxy.java"
                              "MethodInterceptorFilter.java"
                              "MockitoNamingPolicy.java"
                              "SerializableMockitoMethodProxy.java"
                              "SerializableNoOp.java")
                 (("import org.mockito.cglib") "import net.sf.cglib")))
             #t)))))
    (inputs
     `(("java-junit" ,java-junit)
       ("java-objenesis" ,java-objenesis)
       ("java-cglib" ,java-cglib)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://mockito.org")
    (synopsis "Mockito is a mock library for Java")
    (description "Mockito is a mocking library for Java which lets you write
tests with a clean and simple API.  It generates mocks using reflection, and
it records all mock invocations, including methods arguments.")
    (license license:asl2.0)))

(define-public java-httpcomponents-httpcore
  (package
    (name "java-httpcomponents-httpcore")
    (version "4.4.6")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache//httpcomponents/httpcore/"
                                  "source/httpcomponents-core-"
                                  version "-src.tar.gz"))
              (sha256
               (base32
                "02bwcf38y4vgwq7kj2s6q7qrmma641r5lacivm16kgxvb2j6h1vy"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "httpcomponents-httpcore.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'chdir
           (lambda _ (chdir "httpcore") #t)))))
    (inputs
     `(("java-commons-logging-minimal" ,java-commons-logging-minimal)
       ("java-commons-lang3" ,java-commons-lang3)))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-mockito" ,java-mockito-1)))
    (home-page "https://hc.apache.org/httpcomponents-core-4.4.x/index.html")
    (synopsis "Low level HTTP transport components")
    (description "HttpCore is a set of low level HTTP transport components
that can be used to build custom client and server side HTTP services with a
minimal footprint.  HttpCore supports two I/O models: blocking I/O model based
on the classic Java I/O and non-blocking, event driven I/O model based on Java
NIO.

This package provides the blocking I/O model library.")
    (license license:asl2.0)))

(define-public java-httpcomponents-httpcore-nio
  (package (inherit java-httpcomponents-httpcore)
    (name "java-httpcomponents-httpcore-nio")
    (arguments
     `(#:jar-name "httpcomponents-httpcore-nio.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'chdir
           (lambda _ (chdir "httpcore-nio") #t)))))
    (inputs
     `(("java-httpcomponents-httpcore" ,java-httpcomponents-httpcore)
       ("java-hamcrest-core" ,java-hamcrest-core)
       ,@(package-inputs java-httpcomponents-httpcore)))
    (description "HttpCore is a set of low level HTTP transport components
that can be used to build custom client and server side HTTP services with a
minimal footprint.  HttpCore supports two I/O models: blocking I/O model based
on the classic Java I/O and non-blocking, event driven I/O model based on Java
NIO.

This package provides the non-blocking I/O model library based on Java
NIO.")))

(define-public java-httpcomponents-httpcore-ab
  (package (inherit java-httpcomponents-httpcore)
    (name "java-httpcomponents-httpcore-ab")
    (arguments
     `(#:jar-name "httpcomponents-httpcore-ab.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'chdir
           (lambda _ (chdir "httpcore-ab") #t)))))
    (inputs
     `(("java-httpcomponents-httpcore" ,java-httpcomponents-httpcore)
       ("java-commons-cli" ,java-commons-cli)
       ("java-hamcrest-core" ,java-hamcrest-core)
       ,@(package-inputs java-httpcomponents-httpcore)))
    (synopsis "Apache HttpCore benchmarking tool")
    (description "This package provides the HttpCore benchmarking tool.  It is
an Apache AB clone based on HttpCore.")))

(define-public java-httpcomponents-httpclient
  (package
    (name "java-httpcomponents-httpclient")
    (version "4.5.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/httpcomponents/httpclient/"
                                  "source/httpcomponents-client-"
                                  version "-src.tar.gz"))
              (sha256
               (base32
                "1428399s7qy3cim5wc6f3ks4gl9nf9vkjpfmnlap3jflif7g2pj1"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "httpcomponents-httpclient.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'chdir
           (lambda _ (chdir "httpclient") #t)))))
    (inputs
     `(("java-commons-logging-minimal" ,java-commons-logging-minimal)
       ("java-commons-codec" ,java-commons-codec)
       ("java-hamcrest-core" ,java-hamcrest-core)
       ("java-httpcomponents-httpcore" ,java-httpcomponents-httpcore)
       ("java-mockito" ,java-mockito-1)
       ("java-junit" ,java-junit)))
    (home-page "https://hc.apache.org/httpcomponents-client-ga/")
    (synopsis "HTTP client library for Java")
    (description "Although the @code{java.net} package provides basic
functionality for accessing resources via HTTP, it doesn't provide the full
flexibility or functionality needed by many applications.  @code{HttpClient}
seeks to fill this void by providing an efficient, up-to-date, and
feature-rich package implementing the client side of the most recent HTTP
standards and recommendations.")
    (license license:asl2.0)))

(define-public java-httpcomponents-httpmime
  (package (inherit java-httpcomponents-httpclient)
    (name "java-httpcomponents-httpmime")
    (arguments
     `(#:jar-name "httpcomponents-httpmime.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'chdir
           (lambda _ (chdir "httpmime") #t)))))
    (inputs
     `(("java-httpcomponents-httpclient" ,java-httpcomponents-httpclient)
       ("java-httpcomponents-httpcore" ,java-httpcomponents-httpcore)
       ("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))))

(define-public java-commons-net
  (package
    (name "java-commons-net")
    (version "3.6")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/net/source/"
                                  "commons-net-" version "-src.tar.gz"))
              (sha256
               (base32
                "0n0cmnddk9qdqhjvka8pc6hd9mn2qi3166f1s6xk32h7rfy1adxr"))))
    (build-system ant-build-system)
    (arguments
     `(;; FIXME: MainTest.java tries to read "examples.properties" (which
       ;; should be "resources/examples/examples.properties"), but gets "null"
       ;; instead.
       #:tests? #f
       #:jar-name "commons-net.jar"))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://commons.apache.org/net/")
    (synopsis "Client library for many basic Internet protocols")
    (description "The Apache Commons Net library implements the client side of
many basic Internet protocols.  The purpose of the library is to provide
fundamental protocol access, not higher-level abstractions.")
    (license license:asl2.0)))

(define-public java-jsch
  (package
    (name "java-jsch")
    (version "0.1.54")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://sourceforge/jsch/jsch/"
                                  version "/jsch-" version ".zip"))
              (sha256
               (base32
                "029rdddyq1mh3ghryh3ki99kba1xkf1d1swjv2vi6lk6zzjy2wdb"))))
    (build-system ant-build-system)
    (arguments
     `(#:build-target "dist"
       #:tests? #f ; no tests included
       #:phases
       (modify-phases %standard-phases
         (replace 'install (install-jars "dist")))))
    (native-inputs
     `(("unzip" ,unzip)))
    (home-page "http://www.jcraft.com/jsch/")
    (synopsis "Pure Java implementation of SSH2")
    (description "JSch is a pure Java implementation of SSH2.  JSch allows you
to connect to an SSH server and use port forwarding, X11 forwarding, file
transfer, etc., and you can integrate its functionality into your own Java
programs.")
    (license license:bsd-3)))

(define-public java-commons-compress
  (package
    (name "java-commons-compress")
    (version "1.13")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/compress/source/"
                                  "commons-compress-" version "-src.tar.gz"))
              (sha256
               (base32
                "1vjqvavrn0babffn1kciz6v52ibwq2vwhzlb95hazis3lgllnxc8"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "commons-compress.jar"
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'delete-bad-tests
           (lambda _
             (with-directory-excursion "src/test/java/org/apache/commons/compress/"
               ;; FIXME: These tests really should not fail.  Maybe they are
               ;; indicative of problems with our Java packaging work.

               ;; This test fails with a null pointer exception.
               (delete-file "archivers/sevenz/SevenZOutputFileTest.java")
               ;; This test fails to open test resources.
               (delete-file "archivers/zip/ExplodeSupportTest.java")

               ;; FIXME: This test adds a dependency on powermock, which is hard to
               ;; package at this point.
               ;; https://github.com/powermock/powermock
               (delete-file "archivers/sevenz/SevenZNativeHeapTest.java"))
             #t)))))
    (inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)
       ("java-mockito" ,java-mockito-1)
       ("java-xz" ,java-xz)))
    (home-page "https://commons.apache.org/proper/commons-compress/")
    (synopsis "Java library for working with compressed files")
    (description "The Apache Commons Compress library defines an API for
working with compressed files such as ar, cpio, Unix dump, tar, zip, gzip, XZ,
Pack200, bzip2, 7z, arj, lzma, snappy, DEFLATE, lz4 and Z files.")
    (license license:asl2.0)))

(define-public java-commons-net
  (package
    (name "java-commons-net")
    (version "3.6")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/net/source/"
                                  "commons-net-" version "-src.tar.gz"))
              (sha256
               (base32
                "0n0cmnddk9qdqhjvka8pc6hd9mn2qi3166f1s6xk32h7rfy1adxr"))))
    (build-system ant-build-system)
    (arguments
     `(;; FIXME: MainTest.java tries to read "examples.properties" (which
       ;; should be "resources/examples/examples.properties"), but gets "null"
       ;; instead.
       #:tests? #f
       #:jar-name "commons-net.jar"))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://commons.apache.org/net/")
    (synopsis "Client library for many basic Internet protocols")
    (description "The Apache Commons Net library implements the client side of
many basic Internet protocols.  The purpose of the library is to provide
fundamental protocol access, not higher-level abstractions.")
    (license license:asl2.0)))

(define-public java-osgi-annotation
  (package
    (name "java-osgi-annotation")
    (version "6.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/osgi/org.osgi.annotation/" version "/"
                                  "org.osgi.annotation-" version "-sources.jar"))
              (sha256
               (base32
                "1q718mb7gqg726rh6pc2hcisn8v50nv35abbir0jypmffhiii85w"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests
       #:jar-name "osgi-annotation.jar"))
    (home-page "http://www.osgi.org")
    (synopsis "Annotation module of OSGi framework")
    (description
     "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the OSGi annotation module, providing additional services to help dynamic
components.")
    (license license:asl2.0)))

(define-public java-osgi-core
  (package
    (name "java-osgi-core")
    (version "6.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/osgi/org.osgi.core/" version "/"
                                  "org.osgi.core-" version "-sources.jar"))
              (sha256
               (base32
                "19bpf5jx32jq9789gyhin35q5v7flmw0p9mk7wbgqpxqfmxyiabv"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests
       #:jar-name "osgi-core.jar"))
    (inputs
     `(("java-osgi-annotation" ,java-osgi-annotation)))
    (home-page "http://www.osgi.org")
    (synopsis "Core module of OSGi framework")
    (description
     "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the OSGi Core module.")
    (license license:asl2.0)))

(define-public java-osgi-service-event
  (package
    (name "java-osgi-service-event")
    (version "1.3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/osgi/org.osgi.service.event/"
                                  version "/org.osgi.service.event-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1nyhlgagwym75bycnjczwbnpymv2iw84zbhvvzk84g9q736i6qxm"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests
       #:jar-name "osgi-service-event.jar"))
    (inputs
     `(("java-osgi-annotation" ,java-osgi-annotation)
       ("java-osgi-core" ,java-osgi-core)))
    (home-page "http://www.osgi.org")
    (synopsis "OSGi service event module")
    (description
     "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the OSGi @code{org.osgi.service.event} module.")
    (license license:asl2.0)))

(define-public java-eclipse-osgi
  (package
    (name "java-eclipse-osgi")
    (version "3.11.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.osgi/"
                                  version "/org.eclipse.osgi-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "00cqc6lb29n0zv68b4l842vzkwawvbr7gshfdygsk8sicvcq2c7b"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-equinox-osgi.jar"))
    (inputs
     `(("java-osgi-annotation" ,java-osgi-annotation)))
    (home-page "http://www.eclipse.org/equinox/")
    (synopsis "Eclipse Equinox OSGi framework")
    (description "This package provides an implementation of the OSGi Core
specification.")
    (license license:epl1.0)))

(define-public java-eclipse-equinox-common
  (package
    (name "java-eclipse-equinox-common")
    (version "3.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.equinox.common/"
                                  version "/org.eclipse.equinox.common-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "12aazpkgw46r1qj0pr421jzwhbmsizd97r37krd7njnbrdgfzksc"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-equinox-common.jar"))
    (inputs
     `(("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "http://www.eclipse.org/equinox/")
    (synopsis "Common Eclipse runtime")
    (description "This package provides the common Eclipse runtime.")
    (license license:epl1.0)))

(define-public java-eclipse-core-jobs
  (package
    (name "java-eclipse-core-jobs")
    (version "3.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.core.jobs/"
                                  version "/org.eclipse.core.jobs-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0395b8lh0km8vhzjnchvs1rii1qz48hyvb2wqfaq4yhklbwihq4b"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-core-jobs.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "http://www.eclipse.org/equinox/")
    (synopsis "Eclipse jobs mechanism")
    (description "This package provides the Eclipse jobs mechanism.")
    (license license:epl1.0)))

(define-public java-eclipse-equinox-registry
  (package
    (name "java-eclipse-equinox-registry")
    (version "3.6.100")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.equinox.registry/"
                                  version "/org.eclipse.equinox.registry-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1i9sgymh2fy5vdgk5y7s3qvrlbgh4l93ddqi3v4zmca7hwrlhf9k"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-equinox-registry.jar"))
    (inputs
     `(("java-eclipse-core-jobs" ,java-eclipse-core-jobs)
       ("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "http://www.eclipse.org/equinox/")
    (synopsis "Eclipse extension registry support")
    (description "This package provides support for the Eclipse extension
registry.")
    (license license:epl1.0)))

(define-public java-eclipse-equinox-app
  (package
    (name "java-eclipse-equinox-app")
    (version "1.3.400")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.equinox.app/"
                                  version "/org.eclipse.equinox.app-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0nhvbp93y203ar7y59gb0mz3w2d3jlqhr0c9hii9bcfpmr7imdab"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-equinox-app.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-osgi" ,java-eclipse-osgi)
       ("java-osgi-service-event" ,java-osgi-service-event)))
    (home-page "http://www.eclipse.org/equinox/")
    (synopsis "Equinox application container")
    (description "This package provides the Equinox application container for
Eclipse.")
    (license license:epl1.0)))

(define-public java-eclipse-equinox-preferences
  (package
    (name "java-eclipse-equinox-preferences")
    (version "3.6.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.equinox.preferences/"
                                  version "/org.eclipse.equinox.preferences-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0k7w6c141sqym4fy3af0qkwpy4pdh2vsjpjba6rp5fxyqa24v0a2"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-equinox-preferences.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "http://www.eclipse.org/equinox/")
    (synopsis "Eclipse preferences mechanism")
    (description "This package provides the Eclipse preferences mechanism with
the module @code{org.eclipse.equinox.preferences}.")
    (license license:epl1.0)))

(define-public java-eclipse-core-contenttype
  (package
    (name "java-eclipse-core-contenttype")
    (version "3.5.100")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.core.contenttype/"
                                  version "/org.eclipse.core.contenttype-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1wcqcv7ijwv5rh748vz3x9pkmjl9w1r0k0026k56n8yjl4rrmspi"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-core-contenttype.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-preferences" ,java-eclipse-equinox-preferences)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "http://www.eclipse.org/")
    (synopsis "Eclipse content mechanism")
    (description "This package provides the Eclipse content mechanism in the
@code{org.eclipse.core.contenttype} module.")
    (license license:epl1.0)))

(define-public java-eclipse-core-runtime
  (package
    (name "java-eclipse-core-runtime")
    (version "3.12.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.core.runtime/"
                                  version "/org.eclipse.core.runtime-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "16mkf8jgj35pgzms7w1gyfq0gfm4ixw6c5xbbxzdj1la56c758ya"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-core-runtime.jar"))
    (inputs
     `(("java-eclipse-core-contenttype" ,java-eclipse-core-contenttype)
       ("java-eclipse-core-jobs" ,java-eclipse-core-jobs)
       ("java-eclipse-equinox-app" ,java-eclipse-equinox-app)
       ("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-equinox-preferences" ,java-eclipse-equinox-preferences)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "https://www.eclipse.org/")
    (synopsis "Eclipse core runtime")
    (description "This package provides the Eclipse core runtime with the
module @code{org.eclipse.core.runtime}.")
    (license license:epl1.0)))

(define-public java-eclipse-core-filesystem
  (package
    (name "java-eclipse-core-filesystem")
    (version "1.6.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.core.filesystem/"
                                  version "/org.eclipse.core.filesystem-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0km1bhwjim4rfy3pkvjhvy31kgsyf2ncx0mlkmbf5n6g57pphdyj"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-core-filesystem.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "https://www.eclipse.org/")
    (synopsis "Eclipse core file system")
    (description "This package provides the Eclipse core file system with the
module @code{org.eclipse.core.filesystem}.")
    (license license:epl1.0)))

(define-public java-eclipse-core-expressions
  (package
    (name "java-eclipse-core-expressions")
    (version "3.5.100")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.core.expressions/"
                                  version "/org.eclipse.core.expressions-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "18bw2l875gmygvpagpgk9l24qzbdjia4ag12nw6fi8v8yaq4987f"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-core-expressions.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-equinox-preferences" ,java-eclipse-equinox-preferences)
       ("java-eclipse-core-runtime" ,java-eclipse-core-runtime)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "https://www.eclipse.org/")
    (synopsis "Eclipse core expression language")
    (description "This package provides the Eclipse core expression language
with the @code{org.eclipse.core.expressions} module.")
    (license license:epl1.0)))

(define-public java-eclipse-core-variables
  (package
    (name "java-eclipse-core-variables")
    (version "3.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.core.variables/"
                                  version "/org.eclipse.core.variables-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "12dirh03zi4n5x5cj07vzrhkmnqy6h9q10h9j605pagmpmifyxmy"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-core-variables.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-equinox-preferences" ,java-eclipse-equinox-preferences)
       ("java-eclipse-core-runtime" ,java-eclipse-core-runtime)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "https://www.eclipse.org/platform")
    (synopsis "Eclipse core variables")
    (description "This package provides the Eclipse core variables module
@code{org.eclipse.core.variables}.")
    (license license:epl1.0)))

(define-public java-eclipse-ant-core
  (package
    (name "java-eclipse-ant-core")
    (version "3.4.100")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.ant.core/"
                                  version "/org.eclipse.ant.core-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "11g3if794qjlk98mz9zch22rr56sd7z63vn4i7k2icr8cq5bfqg7"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-ant-core.jar"))
    (inputs
     `(("java-eclipse-equinox-app" ,java-eclipse-equinox-app)
       ("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-equinox-preferences" ,java-eclipse-equinox-preferences)
       ("java-eclipse-core-contenttype" ,java-eclipse-core-contenttype)
       ("java-eclipse-core-runtime" ,java-eclipse-core-runtime)
       ("java-eclipse-core-variables" ,java-eclipse-core-variables)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "https://www.eclipse.org/platform")
    (synopsis "Ant build tool core libraries")
    (description "This package provides the ant build tool core libraries with
the module @code{org.eclipse.ant.core}.")
    (license license:epl1.0)))

(define-public java-eclipse-core-resources
  (package
    (name "java-eclipse-core-resources")
    (version "3.11.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.core.resources/"
                                  version "/org.eclipse.core.resources-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1hrfxrll6cpcagfksk2na1ypvkcnsp0fk6n3vcsrn97qayf9mx9l"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-core-resources.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-preferences" ,java-eclipse-equinox-preferences)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-core-contenttype" ,java-eclipse-core-contenttype)
       ("java-eclipse-core-expressions" ,java-eclipse-core-expressions)
       ("java-eclipse-core-filesystem" ,java-eclipse-core-filesystem)
       ("java-eclipse-core-jobs" ,java-eclipse-core-jobs)
       ("java-eclipse-core-runtime" ,java-eclipse-core-runtime)
       ("java-eclipse-ant-core" ,java-eclipse-ant-core)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "https://www.eclipse.org/")
    (synopsis "Eclipse core resource management")
    (description "This package provides the Eclipse core resource management
module @code{org.eclipse.core.resources}.")
    (license license:epl1.0)))

(define-public java-eclipse-compare-core
  (package
    (name "java-eclipse-compare-core")
    (version "3.6.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.compare.core/"
                                  version "/org.eclipse.compare.core-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "10g37r0pbiffyv2wk35c6g5lwzkdipkl0kkjp41v84dln46xm4dg"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-compare-core.jar"))
    (inputs
     `(("java-eclipse-core-runtime" ,java-eclipse-core-runtime)
       ("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-osgi" ,java-eclipse-osgi)
       ("java-icu4j" ,java-icu4j)))
    (home-page "https://www.eclipse.org/")
    (synopsis "Eclipse core compare support")
    (description "This package provides the Eclipse core compare support
module @code{org.eclipse.compare.core}.")
    (license license:epl1.0)))

(define-public java-eclipse-team-core
  (package
    (name "java-eclipse-team-core")
    (version "3.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.team.core/"
                                  version "/org.eclipse.team.core-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "02j2jzqgb26zx2d5ahxmvijw6j4r0la90zl5c3i65x6z19ciyam7"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-team-core.jar"))
    (inputs
     `(("java-eclipse-compare-core" ,java-eclipse-compare-core)
       ("java-eclipse-core-contenttype" ,java-eclipse-core-contenttype)
       ("java-eclipse-core-filesystem" ,java-eclipse-core-filesystem)
       ("java-eclipse-core-jobs" ,java-eclipse-core-jobs)
       ("java-eclipse-core-resources" ,java-eclipse-core-resources)
       ("java-eclipse-core-runtime" ,java-eclipse-core-runtime)
       ("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-equinox-preferences" ,java-eclipse-equinox-preferences)
       ("java-eclipse-osgi" ,java-eclipse-osgi)))
    (home-page "https://www.eclipse.org/platform")
    (synopsis "Eclipse team support core")
    (description "This package provides the Eclipse team support core module
@code{org.eclipse.team.core}.")
    (license license:epl1.0)))

(define-public java-eclipse-core-commands
  (package
    (name "java-eclipse-core-commands")
    (version "3.8.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.core.commands/"
                                  version "/org.eclipse.core.commands-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0yjn482qndcfrsq3jd6vnhcylp16420f5aqkrwr8spsprjigjcr9"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-core-commands.jar"))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)))
    (home-page "https://www.eclipse.org/platform")
    (synopsis "Eclipse core commands")
    (description "This package provides Eclipse core commands in the module
@code{org.eclipse.core.commands}.")
    (license license:epl1.0)))

(define-public java-eclipse-text
  (package
    (name "java-eclipse-text")
    (version "3.6.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/platform/org.eclipse.text/"
                                  version "/org.eclipse.text-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0scz70vzz5qs5caji9f5q01vkqnvip7dpri1q07l8wbbdcxn4cq1"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-text.jar"
       #:phases
       (modify-phases %standard-phases
         ;; When creating a new category we must make sure that the new list
         ;; matches List<Position>.  By default it seems to be too generic
         ;; (ArrayList<Object>), so we specialize it to ArrayList<Position>.
         ;; Without this we get this error:
         ;;
         ;; [javac] .../src/org/eclipse/jface/text/AbstractDocument.java:376:
         ;;      error: method put in interface Map<K,V> cannot be applied to given types;
         ;; [javac] 			fPositions.put(category, new ArrayList<>());
         ;; [javac] 			          ^
         ;; [javac]   required: String,List<Position>
         ;; [javac]   found: String,ArrayList<Object>
         ;; [javac]   reason: actual argument ArrayList<Object> cannot be converted
         ;;              to List<Position> by method invocation conversion
         ;; [javac]   where K,V are type-variables:
         ;; [javac]     K extends Object declared in interface Map
         ;; [javac]     V extends Object declared in interface Map
         ;;
         ;; I don't know if this is a good fix.  I suspect it is not, but it
         ;; seems to work.
         (add-after 'unpack 'fix-compilation-error
           (lambda _
             (substitute* "src/org/eclipse/jface/text/AbstractDocument.java"
               (("Positions.put\\(category, new ArrayList<>\\(\\)\\);")
                "Positions.put(category, new ArrayList<Position>());"))
             #t)))))
    (inputs
     `(("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-core-commands" ,java-eclipse-core-commands)
       ("java-icu4j" ,java-icu4j)))
    (home-page "http://www.eclipse.org/platform")
    (synopsis "Eclipse text library")
    (description "Platform Text is part of the Platform UI project and
provides the basic building blocks for text and text editors within Eclipse
and contributes the Eclipse default text editor.")
    (license license:epl1.0)))

(define-public java-eclipse-jdt-core
  (package
    (name "java-eclipse-jdt-core")
    (version "3.12.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "org/eclipse/jdt/org.eclipse.jdt.core/"
                                  version "/org.eclipse.jdt.core-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "191xw4lc7mjjkprh4ji5vnpjvr5r4zvbpwkriy4bvsjqrz35vh1j"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests included
       #:jar-name "eclipse-jdt-core.jar"))
    (inputs
     `(("java-eclipse-core-contenttype" ,java-eclipse-core-contenttype)
       ("java-eclipse-core-filesystem" ,java-eclipse-core-filesystem)
       ("java-eclipse-core-jobs" ,java-eclipse-core-jobs)
       ("java-eclipse-core-resources" ,java-eclipse-core-resources)
       ("java-eclipse-core-runtime" ,java-eclipse-core-runtime)
       ("java-eclipse-equinox-app" ,java-eclipse-equinox-app)
       ("java-eclipse-equinox-common" ,java-eclipse-equinox-common)
       ("java-eclipse-equinox-preferences" ,java-eclipse-equinox-preferences)
       ("java-eclipse-equinox-registry" ,java-eclipse-equinox-registry)
       ("java-eclipse-osgi" ,java-eclipse-osgi)
       ("java-eclipse-text" ,java-eclipse-text)))
    (home-page "https://www.eclipse.org/jdt")
    (synopsis "Java development tools core libraries")
    (description "This package provides the core libraries of the Eclipse Java
development tools.")
    (license license:epl1.0)))

(define-public java-javax-mail
  (package
    (name "java-javax-mail")
    (version "1.5.6")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://repo1.maven.org/maven2/"
                                  "com/sun/mail/javax.mail/"
                                  version "/javax.mail-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0sdlfgsc2b5s89xv1261y8i0jijcja019k2x1c8ngfn582w4jly9"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; no tests
       #:jar-name "javax-mail.jar"))
    (home-page "https://javamail.java.net")
    (synopsis "Reference implementation of the JavaMail API")
    (description
     "This package provides versions of the JavaMail API implementation, IMAP,
SMTP, and POP3 service providers, some examples, and documentation for the
JavaMail API.")
    ;; GPLv2 only with "classpath exception".
    (license license:gpl2)))

(define-public java-log4j-api
  (package
    (name "java-log4j-api")
    (version "2.4.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/logging/log4j/" version
                                  "/apache-log4j-" version "-src.tar.gz"))
              (sha256
               (base32
                "0j5p9gik0jysh37nlrckqbky12isy95cpwg2gv5fas1rcdqbraxd"))))
    (build-system ant-build-system)
    (arguments
     `(#:tests? #f ; tests require unpackaged software
       #:jar-name "log4j-api.jar"
       #:make-flags
       (list (string-append "-Ddist.dir=" (assoc-ref %outputs "out")
                            "/share/java"))
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'enter-dir
           (lambda _ (chdir "log4j-api") #t))
         ;; FIXME: The tests require additional software that has not been
         ;; packaged yet, such as
         ;; * org.apache.maven
         ;; * org.apache.felix
         (add-after 'enter-dir 'delete-tests
           (lambda _ (delete-file-recursively "src/test") #t)))))
    (inputs
     `(("java-osgi-core" ,java-osgi-core)
       ("java-hamcrest-core" ,java-hamcrest-core)
       ("java-junit" ,java-junit)))
    (home-page "http://logging.apache.org/log4j/2.x/")
    (synopsis "API module of the Log4j logging framework for Java")
    (description
     "This package provides the API module of the Log4j logging framework for
Java.")
    (license license:asl2.0)))

(define-public java-commons-cli
  (package
    (name "java-commons-cli")
    (version "1.3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/cli/source/"
                                  "commons-cli-" version "-src.tar.gz"))
              (sha256
               (base32
                "1fkjn552i12vp3xxk21ws4p70fi0lyjm004vzxsdaz7gdpgyxxyl"))))
    (build-system ant-build-system)
    ;; TODO: javadoc
    (arguments
     `(#:jar-name "commons-cli.jar"))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://commons.apache.org/cli/")
    (synopsis "Command line arguments and options parsing library")
    (description "The Apache Commons CLI library provides an API for parsing
command line options passed to programs.  It is also able to print help
messages detailing the options available for a command line tool.

Commons CLI supports different types of options:

@itemize
@item POSIX like options (ie. tar -zxvf foo.tar.gz)
@item GNU like long options (ie. du --human-readable --max-depth=1)
@item Java like properties (ie. java -Djava.awt.headless=true Foo)
@item Short options with value attached (ie. gcc -O2 foo.c)
@item long options with single hyphen (ie. ant -projecthelp)
@end itemize

This is a part of the Apache Commons Project.")
    (license license:asl2.0)))

(define-public java-commons-codec
  (package
    (name "java-commons-codec")
    (version "1.10")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/codec/source/"
                                  "commons-codec-" version "-src.tar.gz"))
              (sha256
               (base32
                "1w9qg30y4s0x8gnmr2fgj4lyplfn788jqxbcz27lf5kbr6n8xr65"))))
    (build-system ant-build-system)
    (outputs '("out" "doc"))
    (arguments
     `(#:test-target "test"
       #:make-flags
       (let ((hamcrest (assoc-ref %build-inputs "java-hamcrest-core"))
             (junit    (assoc-ref %build-inputs "java-junit")))
         (list (string-append "-Djunit.jar=" junit "/share/java/junit.jar")
               (string-append "-Dhamcrest.jar=" hamcrest
                              "/share/java/hamcrest-core.jar")
               ;; Do not append version to jar.
               "-Dfinal.name=commons-codec"))
       #:phases
       (modify-phases %standard-phases
         (add-after 'build 'build-javadoc ant-build-javadoc)
         (replace 'install (install-jars "dist"))
         (add-after 'install 'install-doc (install-javadoc "dist/docs/api")))))
    (native-inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "http://commons.apache.org/codec/")
    (synopsis "Common encoders and decoders such as Base64, Hex, Phonetic and URLs")
    (description "The codec package contains simple encoder and decoders for
various formats such as Base64 and Hexadecimal.  In addition to these widely
used encoders and decoders, the codec package also maintains a collection of
phonetic encoding utilities.

This is a part of the Apache Commons Project.")
    (license license:asl2.0)))

(define-public java-commons-daemon
  (package
    (name "java-commons-daemon")
    (version "1.0.15")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/daemon/source/"
                                  "commons-daemon-" version "-src.tar.gz"))
              (sha256
               (base32
                "0ci46kq8jpz084ccwq0mmkahcgsmh20ziclp2jf5i0djqv95gvhi"))))
    (build-system ant-build-system)
    (arguments
     `(#:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-after 'build 'build-javadoc ant-build-javadoc)
         (replace 'install (install-jars "dist"))
         (add-after 'install 'install-doc (install-javadoc "dist/docs/api")))))
    (native-inputs
     `(("java-junit" ,java-junit)))
    (home-page "http://commons.apache.org/daemon/")
    (synopsis "Library to launch Java applications as daemons")
    (description "The Daemon package from Apache Commons can be used to
implement Java applications which can be launched as daemons.  For example the
program will be notified about a shutdown so that it can perform cleanup tasks
before its process of execution is destroyed by the operation system.

This package contains the Java library.  You will also need the actual binary
for your architecture which is provided by the jsvc package.

This is a part of the Apache Commons Project.")
    (license license:asl2.0)))

(define-public java-javaewah
  (package
    (name "java-javaewah")
    (version "1.1.6")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/lemire/javaewah/"
                                  "archive/JavaEWAH-" version ".tar.gz"))
              (sha256
               (base32
                "1n7j1r1h24wlhwv9zdcj6yqjrhma2ixwyzm15l5vrv6yqjs6753b"))))
    (build-system ant-build-system)
    (arguments `(#:jar-name "javaewah.jar"))
    (inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "https://github.com/lemire/javaewah")
    (synopsis "Compressed alternative to the Java @code{BitSet} class")
    (description "This is a word-aligned compressed variant of the Java
@code{Bitset} class.  It provides both a 64-bit and a 32-bit RLE-like
compression scheme.  It can be used to implement bitmap indexes.

The goal of word-aligned compression is not to achieve the best compression,
but rather to improve query processing time. Hence, JavaEWAH tries to save CPU
cycles, maybe at the expense of storage.  However, the EWAH scheme is always
more efficient storage-wise than an uncompressed bitmap (as implemented in the
@code{BitSet} class by Sun).")
    ;; GPL2.0 derivates are explicitly allowed.
    (license license:asl2.0)))

(define-public java-slf4j-api
  (package
    (name "java-slf4j-api")
    (version "1.7.25")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://www.slf4j.org/dist/slf4j-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "13j51sgzmhhdrfa74gkal5zpip7r1440dh7zsi2c8bpb2zs1v8kb"))
              (modules '((guix build utils)))
              ;; Delete bundled jars.
              (snippet
               '(begin
                  (for-each delete-file (find-files "." "\\.jar$"))
                  #t))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "slf4j-api.jar"
       #:source-dir "slf4j-api/src/main"
       #:test-dir "slf4j-api/src/test"
       #:phases
       (modify-phases %standard-phases
         (add-after 'build 'regenerate-jar
           (lambda _
             ;; pom.xml ignores these files in the jar creation process. If we don't,
             ;; we get the error "This code should have never made it into slf4j-api.jar"
             (delete-file-recursively "build/classes/org/slf4j/impl")
             (zero? (system* "jar" "-cf" "build/jar/slf4j-api.jar" "-C"
                             "build/classes" "."))))
         (add-before 'check 'dont-test-abstract-classes
           (lambda _
             ;; abstract classes are not meant to be run with junit
             (substitute* "build.xml"
               (("<include name=\"\\*\\*/\\*Test.java\" />")
                (string-append "<include name=\"**/*Test.java\" />"
                               "<exclude name=\"**/MultithreadedInitializationTest"
                               ".java\" />"))))))))
    (inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)))
    (home-page "https://www.slf4j.org/")
    (synopsis "Simple logging facade for Java")
    (description "The Simple Logging Facade for Java (SLF4J) serves as a
simple facade or abstraction for various logging
frameworks (e.g. @code{java.util.logging}, @code{logback}, @code{log4j})
allowing the end user to plug in the desired logging framework at deployment
time.")
    (license license:expat)))

(define-public java-slf4j-simple
  (package
    (name "java-slf4j-simple")
    (version "1.7.25")
    (source (package-source java-slf4j-api))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "slf4j-simple.jar"
       #:source-dir "slf4j-simple/src/main"
       #:test-dir "slf4j-simple/src/test"
       #:phases
       (modify-phases %standard-phases
         ;; The tests need some test classes from slf4j-api
         (add-before 'check 'build-slf4j-api-test-helpers
           (lambda _
             ;; Add current dir to CLASSPATH ...
             (setenv "CLASSPATH"
                     (string-append (getcwd) ":" (getenv "CLASSPATH")))
             ;; ... and build test helper classes here:
             (zero?
              (apply system*
                     `("javac" "-d" "."
                       ,@(find-files "slf4j-api/src/test" ".*\\.java")))))))))
    (inputs
     `(("java-junit" ,java-junit)
       ("java-hamcrest-core" ,java-hamcrest-core)
       ("java-slf4j-api" ,java-slf4j-api)))
    (home-page "https://www.slf4j.org/")
    (synopsis "Simple implementation of simple logging facade for Java")
    (description "SLF4J binding for the Simple implementation, which outputs
all events to System.err.  Only messages of level INFO and higher are
printed.")
    (license license:expat)))

(define-public antlr2
  (package
    (name "antlr2")
    (version "2.7.7")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://www.antlr2.org/download/antlr-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "1ffvcwdw73id0dk6pj2mlxjvbg0662qacx4ylayqcxgg381fnfl5"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  (delete-file "antlr.jar")
                  (substitute* "lib/cpp/antlr/CharScanner.hpp"
                    (("#include <map>")
                     (string-append
                      "#include <map>\n"
                      "#define EOF (-1)\n"
                      "#include <strings.h>")))
                  (substitute* "configure"
                    (("/bin/sh") "sh"))
                  #t))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f ; no test target
       #:imported-modules ((guix build ant-build-system)
                           (guix build syscalls)
                           ,@%gnu-build-system-modules)
       #:modules (((guix build ant-build-system) #:prefix ant:)
                  (guix build gnu-build-system)
                  (guix build utils))
       #:phases
       (modify-phases %standard-phases
         (add-after 'install 'strip-jar-timestamps
           (assoc-ref ant:%standard-phases 'strip-jar-timestamps))
         (add-after 'configure 'fix-bin-ls
           (lambda _
             (substitute* (find-files "." "Makefile")
               (("/bin/ls") "ls"))
             #t)))))
    (native-inputs
     `(("which" ,which)
       ("zip" ,zip)
       ("java" ,icedtea "jdk")))
    (inputs
     `(("java" ,icedtea)))
    (home-page "http://www.antlr2.org")
    (synopsis "Framework for constructing recognizers, compilers, and translators")
    (description "ANTLR, ANother Tool for Language Recognition, (formerly PCCTS)
is a language tool that provides a framework for constructing recognizers,
compilers, and translators from grammatical descriptions containing Java, C#,
C++, or Python actions.  ANTLR provides excellent support for tree construction,
tree walking, and translation.")
    (license license:public-domain)))

(define-public java-stringtemplate-3
  (package
    (name "java-stringtemplate")
    (version "3.2.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/antlr/website-st4/raw/"
                                  "gh-pages/download/stringtemplate-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "086yj68np1vqhkj7483diz3km6s6y4gmwqswa7524a0ca6vxn2is"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name (string-append ,name "-" ,version ".jar")
       #:test-dir "test"
       #:modules ((guix build ant-build-system)
                  (guix build utils)
                  (srfi srfi-1))
       #:phases
       (modify-phases %standard-phases
         (add-before 'check 'fix-tests
           (lambda _
             (substitute* "build.xml"
               (("\\$\\{test.home\\}/java")
                "${test.home}/org"))
             #t))
         (add-before 'build 'generate-grammar
           (lambda _
             (with-directory-excursion "src/org/antlr/stringtemplate/language/"
               (every (lambda (file)
                        (format #t "~a\n" file)
                        (zero? (system* "antlr" file)))
                      '("template.g" "angle.bracket.template.g" "action.g"
                        "eval.g" "group.g" "interface.g"))))))))
    (native-inputs
     `(("antlr" ,antlr2)
       ("java-junit" ,java-junit)))
    (home-page "http://www.stringtemplate.org")
    (synopsis "Template engine to generate formatted text output")
    (description "StringTemplate is a java template engine (with ports for C#,
Objective-C, JavaScript, Scala) for generating source code, web pages, emails,
or any other formatted text output.  StringTemplate is particularly good at
code generators, multiple site skins, and internationalization / localization.
StringTemplate also powers ANTLR.")
    (license license:bsd-3)))

;; antlr3 is partially written using antlr3 grammar files. It also depends on
;; ST4 (stringtemplate4), which is also partially written using antlr3 grammar
;; files and uses antlr3 at runtime. The latest version requires a recent version
;; of antlr3 at runtime.
;; Fortunately, ST4 4.0.6 can be built with an older antlr3, and we use antlr3.3.
;; This version of ST4 is sufficient for the latest antlr3.
;; We use ST4 4.0.6 to build a boostrap antlr3 (latest version), and build
;; the latest ST4 with it. Then we build our final antlr3 that will be linked
;; against the latest ST4.
;; antlr3.3 still depends on antlr3 to generate some files, so we use an
;; even older version, antlr3.1, to generate them. Fortunately antlr3.1 uses
;; only grammar files with the antlr2 syntax.
;; So we build antlr3.1 -> antlr3.3 -> ST4.0.6 -> antlr3-bootstrap -> ST4 -> antlr3.

(define-public java-stringtemplate
  (package (inherit java-stringtemplate-3)
    (name "java-stringtemplate")
    (version "4.0.8")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/antlr/stringtemplate4/archive/"
                                  version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "1pri8hqa95rfdkjy55icl5q1m09zwp5k67ib14abas39s4v3w087"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name (string-append ,name "-" ,version ".jar")
       #:tests? #f ; FIXME: tests fail for unknown reasons
       #:test-dir "test"
       #:modules ((guix build ant-build-system)
                  (guix build utils)
                  (srfi srfi-1))
       #:phases
       (modify-phases %standard-phases
         (add-before 'check 'fix-test-target
           (lambda _
             (substitute* "build.xml"
               (("\\$\\{test.home\\}/java") "${test.home}/")
               (("\\*Test.java") "Test*.java"))
             #t))
         (add-before 'build 'generate-grammar
           (lambda _
             (with-directory-excursion "src/org/stringtemplate/v4/compiler/"
               (every (lambda (file)
                        (format #t "~a\n" file)
                        (zero? (system* "antlr3" file)))
                      '("STParser.g" "Group.g" "CodeGenerator.g"))))))))
    (inputs
     `(("antlr3" ,antlr3-bootstrap)
       ("antlr2" ,antlr2)
       ("java-stringtemplate" ,java-stringtemplate-3)
       ("java-junit" ,java-junit)))))

(define java-stringtemplate-4.0.6
  (package (inherit java-stringtemplate)
    (name "java-stringtemplate")
    (version "4.0.6")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/antlr/stringtemplate4/archive/ST-"
                                  version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "0hjmh1ahdsh3w825i67mli9l4nncc4l6hdbf9ma91jvlj590sljp"))))
    (inputs
     `(("antlr3" ,antlr3-3.3)
       ("antlr2" ,antlr2)
       ("java-stringtemplate" ,java-stringtemplate-3)))))

(define-public antlr3
  (package
    (name "antlr3")
    (version "3.5.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/antlr/antlr3/archive/"
                                  version ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "07zff5frmjd53rnqdx31h0pmswz1lv0p2lp28cspfszh25ysz6sj"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name (string-append ,name "-" ,version ".jar")
       #:source-dir "tool/src/main/java:runtime/Java/src/main/java:tool/src/main/antlr3"
       #:tests? #f
       #:phases
       (modify-phases %standard-phases
         (add-after 'install 'bin-install
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((jar (string-append (assoc-ref outputs "out") "/share/java"))
                   (bin (string-append (assoc-ref outputs "out") "/bin")))
               (mkdir-p bin)
               (with-output-to-file (string-append bin "/antlr3")
                 (lambda _
                   (display
                     (string-append "#!" (which "sh") "\n"
                                    "java -cp " jar "/" ,name "-" ,version ".jar:"
                                    (string-concatenate
                                      (find-files (assoc-ref inputs "stringtemplate")
                                                  ".*\\.jar"))
                                    ":"
                                    (string-concatenate
                                      (find-files (assoc-ref inputs "stringtemplate4")
                                                  ".*\\.jar"))
                                    ":"
                                    (string-concatenate
                                      (find-files (string-append
                                                    (assoc-ref inputs "antlr")
                                                    "/lib")
                                                  ".*\\.jar"))
                                    " org.antlr.Tool $*"))))
               (chmod (string-append bin "/antlr3") #o755))))
         (add-before 'build 'generate-grammar
           (lambda _
             (chdir "tool/src/main/antlr3/org/antlr/grammar/v3/")
             (for-each (lambda (file)
                         (display file)
                         (newline)
                         (system* "antlr3" file))
                       '("ANTLR.g" "ANTLRTreePrinter.g" "ActionAnalysis.g"
                         "AssignTokenTypesWalker.g"
                         "ActionTranslator.g" "TreeToNFAConverter.g"
                         "ANTLRv3.g" "ANTLRv3Tree.g" "LeftRecursiveRuleWalker.g"
                         "CodeGenTreeWalker.g" "DefineGrammarItemsWalker.g"))
             (substitute* "ANTLRParser.java"
               (("public Object getTree") "public GrammarAST getTree"))
             (substitute* "ANTLRv3Parser.java"
               (("public Object getTree") "public CommonTree getTree"))
             (chdir "../../../../../java")
             (system* "antlr" "-o" "org/antlr/tool"
                      "org/antlr/tool/serialize.g")
             (substitute* "org/antlr/tool/LeftRecursiveRuleAnalyzer.java"
               (("import org.antlr.grammar.v3.\\*;") "import org.antlr.grammar.v3.*;
import org.antlr.grammar.v3.ANTLRTreePrinter;"))
             (substitute* "org/antlr/tool/ErrorManager.java"
               (("case NO_SUCH_ATTRIBUTE_PASS_THROUGH:") ""))
             (chdir "../../../..")))
         (add-before 'build 'fix-build-xml
           (lambda _
             (substitute* "build.xml"
               (("<exec") "<copy todir=\"${classes.dir}\">
<fileset dir=\"tool/src/main/resources\">
<include name=\"**/*.stg\"/>
<include name=\"**/*.st\"/>
<include name=\"**/*.sti\"/>
<include name=\"**/STLexer.tokens\"/>
</fileset>
</copy><exec")))))))
    (native-inputs
     `(("antlr" ,antlr2)
       ("antlr3" ,antlr3-bootstrap)))
    (inputs
     `(("junit" ,java-junit)
       ("stringtemplate" ,java-stringtemplate-3)
       ("stringtemplate4" ,java-stringtemplate)))
    (propagated-inputs
     `(("stringtemplate" ,java-stringtemplate-3)
       ("antlr" ,antlr2)
       ("stringtemplate4" ,java-stringtemplate-4.0.6)))
    (home-page "http://www.antlr3.org")
    (synopsis "Framework for constructing recognizers, compilers, and translators")
    (description "ANTLR, ANother Tool for Language Recognition, (formerly PCCTS)
is a language tool that provides a framework for constructing recognizers,
compilers, and translators from grammatical descriptions containing Java, C#,
C++, or Python actions.  ANTLR provides excellent support for tree construction,
tree walking, and translation.")
    (license license:bsd-3)))

(define antlr3-bootstrap
  (package
    (inherit antlr3)
    (name "antlr3-bootstrap")
    (native-inputs
     `(("antlr" ,antlr2)
       ("antlr3" ,antlr3-3.3)))
    (inputs
     `(("junit" ,java-junit)))))

(define antlr3-3.3
  (package
    (inherit antlr3)
    (name "antlr3")
    (version "3.3")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/antlr/website-antlr3/raw/"
                                  "gh-pages/download/antlr-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "0qgg5vgsm4l1d6dj9pfbaa25dpv2ry2gny8ajy4vvgvfklw97b3m"))))
    (arguments
     `(#:jar-name (string-append ,name "-" ,version ".jar")
       #:source-dir (string-append "tool/src/main/java:runtime/Java/src/main/java:"
                                "tool/src/main/antlr2:tool/src/main/antlr3")
       #:tests? #f
       #:phases
       (modify-phases %standard-phases
         (add-after 'install 'bin-install
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((jar (string-append (assoc-ref outputs "out") "/share/java"))
                   (bin (string-append (assoc-ref outputs "out") "/bin")))
               (mkdir-p bin)
               (with-output-to-file (string-append bin "/antlr3")
                 (lambda _
                   (display
                     (string-append "#!" (which "sh") "\n"
                                    "java -cp " jar "/antlr3-3.3.jar:"
                                    (string-concatenate
                                      (find-files (assoc-ref inputs "java-stringtemplate")
                                                  ".*\\.jar"))
                                    ":"
                                    (string-concatenate
                                      (find-files (string-append
                                                    (assoc-ref inputs "antlr")
                                                    "/lib")
                                                  ".*\\.jar"))
                                    " org.antlr.Tool $*"))))
               (chmod (string-append bin "/antlr3") #o755))))
         (add-before 'build 'generate-grammar
           (lambda _
             (let ((dir "tool/src/main/antlr2/org/antlr/grammar/v2/"))
               (for-each (lambda (file)
                           (display file)
                           (newline)
                           (system* "antlr" "-o" dir (string-append dir file)))
                         '("antlr.g" "antlr.print.g" "assign.types.g"
                           "buildnfa.g" "codegen.g" "define.g")))
             (chdir "tool/src/main/antlr3/org/antlr/grammar/v3/")
             (for-each (lambda (file)
                         (display file)
                         (newline)
                         (system* "antlr3" file))
                       '("ActionAnalysis.g" "ActionTranslator.g" "ANTLRv3.g"
                         "ANTLRv3Tree.g"))
             (chdir "../../../../../../../..")
             (substitute* "tool/src/main/java/org/antlr/tool/Grammar.java"
               (("import org.antlr.grammar.v2.\\*;")
                "import org.antlr.grammar.v2.*;\n
import org.antlr.grammar.v2.TreeToNFAConverter;\n
import org.antlr.grammar.v2.DefineGrammarItemsWalker;\n
import org.antlr.grammar.v2.ANTLRTreePrinter;"))))
         (add-before 'build 'fix-build-xml
           (lambda _
             (substitute* "build.xml"
               (("<exec") "<copy todir=\"${classes.dir}\">
<fileset dir=\"tool/src/main/resources\">
<include name=\"**/*.stg\"/>
<include name=\"**/*.st\"/>
<include name=\"**/*.sti\"/>
<include name=\"**/STLexer.tokens\"/>
</fileset>
</copy><exec")))))))
    (native-inputs
     `(("antlr" ,antlr2)
       ("antlr3" ,antlr3-3.1)))
    (inputs
     `(("junit" ,java-junit)))
    (propagated-inputs
     `(("java-stringtemplate" ,java-stringtemplate-3)
       ("antlr" ,antlr2)
       ("antlr3" ,antlr3-3.1)))))

(define antlr3-3.1
  (package
    (inherit antlr3)
    (name "antlr3-3.1")
    (version "3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/antlr/website-antlr3/raw/"
                                  "gh-pages/download/antlr-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "0sfimc9cpbgrihz4giyygc8afgpma2c93yqpwb951giriri6x66z"))))
    (arguments
     `(#:jar-name (string-append ,name "-" ,version ".jar")
       #:source-dir "src:runtime/Java/src"
       #:tests? #f
       #:phases
       (modify-phases %standard-phases
         (add-after 'install 'bin-install
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let ((jar (string-append (assoc-ref outputs "out") "/share/java"))
                   (bin (string-append (assoc-ref outputs "out") "/bin")))
               (mkdir-p bin)
               (with-output-to-file (string-append bin "/antlr3")
                 (lambda _
                   (display
                     (string-append "#!" (which "sh") "\n"
                                    "java -cp " jar "/antlr3-3.1-3.1.jar:"
                                    (string-concatenate
                                      (find-files (assoc-ref inputs "stringtemplate")
                                                  ".*\\.jar"))
                                    ":"
                                    (string-concatenate
                                      (find-files (string-append
                                                    (assoc-ref inputs "antlr")
                                                    "/lib")
                                                  ".*\\.jar"))
                                    " org.antlr.Tool $*"))))
               (chmod (string-append bin "/antlr3") #o755))))
         (add-before 'build 'generate-grammar
           (lambda _
             (let ((dir "src/org/antlr/tool/"))
               (for-each (lambda (file)
                           (display file)
                           (newline)
                           (system* "antlr" "-o" dir (string-append dir file)))
                         '("antlr.g" "antlr.print.g" "assign.types.g"
                           "buildnfa.g" "define.g")))
             (format #t "codegen.g\n")
             (system* "antlr" "-o" "src/org/antlr/codegen"
                      "src/org/antlr/codegen/codegen.g")))
         (add-before 'build 'fix-build-xml
           (lambda _
             (substitute* "build.xml"
               (("<exec") "<copy todir=\"${classes.dir}\">
<fileset dir=\"src\">
<include name=\"**/*.stg\"/>
<include name=\"**/*.st\"/>
<include name=\"**/*.sti\"/>
<include name=\"**/STLexer.tokens\"/>
</fileset>
</copy><exec")))))))
    (native-inputs
     `(("antlr" ,antlr2)))
    (inputs
     `(("junit" ,java-junit)))
    (propagated-inputs
     `(("stringtemplate" ,java-stringtemplate-3)))))

(define-public java-asm
  (package
    (name "java-asm")
    (version "5.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://download.forge.ow2.org/asm/"
                                  "asm-" version ".tar.gz"))
              (sha256
               (base32
                "0kxvmv5275rnjl7jv0442k3wjnq03ngkb7sghs78avf45pzm4qgr"))))
    (build-system ant-build-system)
    (arguments
     `(#:build-target "compile"
       #:test-target "test"
       ;; The tests require an old version of Janino, which no longer compiles
       ;; with the JDK7.
       #:tests? #f
       ;; We don't need these extra ant tasks, but the build system asks us to
       ;; provide a path anyway.
       #:make-flags (list (string-append "-Dobjectweb.ant.tasks.path=foo"))
       #:phases
       (modify-phases %standard-phases
         (add-before 'install 'build-jars
           (lambda* (#:key make-flags #:allow-other-keys)
             ;; We cannot use the "jar" target because it depends on a couple
             ;; of unpackaged, complicated tools.
             (mkdir "dist")
             (zero? (system* "jar"
                             "-cf" (string-append "dist/asm-" ,version ".jar")
                             "-C" "output/build/tmp" "."))))
         (replace 'install
           (install-jars "dist")))))
    (native-inputs
     `(("java-junit" ,java-junit)))
    (home-page "http://asm.ow2.org/")
    (synopsis "Very small and fast Java bytecode manipulation framework")
    (description "ASM is an all purpose Java bytecode manipulation and
analysis framework.  It can be used to modify existing classes or dynamically
generate classes, directly in binary form.  The provided common
transformations and analysis algorithms allow to easily assemble custom
complex transformations and code analysis tools.")
    (license license:bsd-3)))

(define-public java-commons-cli-1.2
  ;; This is a bootstrap dependency for Maven2.
  (package
    (inherit java-commons-cli)
    (version "1.2")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://apache/commons/cli/source/"
                                  "commons-cli-" version "-src.tar.gz"))
              (sha256
               (base32
                "0rvfgzgv2pc1m091dfj3ih9ddsjjppr1f1wf0qmc3bk6b1kwv2dm"))))
    (arguments
     `(#:jar-name "commons-cli.jar"
       #:phases
       (modify-phases %standard-phases
         (add-before 'check 'fix-build-xml
           (lambda* (#:key inputs #:allow-other-keys)
             (substitute* "build.xml"
               (("dir=\"\\$\\{test.home\\}/java\"")
                "dir=\"${test.home}\""))
             #t)))))
    (native-inputs
     `(("java-junit" ,java-junit)))))

(define-public java-microemulator-cldc
  (package
    (name "java-microemulator-cldc")
    (version "2.0.4")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/barteo/microemu/archive/"
                                  "microemulator_"
                                  (string-map (lambda (c) (if (char=? c #\.) #\_ c))
                                              version)
                                  ".tar.gz"))
              (file-name (string-append name "-" version ".tar.gz"))
              (sha256
               (base32
                "1x1apmz38gkppxnwnygwmi12j54v4p258v8ddzn6dldkk7vak1ll"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "microemulator-cldc.jar"
       #:source-dir "microemu-cldc/src/main/java"
       #:tests? #f)); Requires even older software
    (home-page "https://github.com/barteo/microemu")
    (synopsis "J2ME CLDC emulator")
    (description "Microemulator is a Java 2 Micro Edition (J2ME) CLDC/MIDP
Emulator.  It allows to demonstrate MIDlet based applications in web browser
applet and can be run as a standalone java application.")
    (license (list license:asl2.0
                   ;; or altenatively:
                   license:lgpl2.1+))))

(define-public java-datanucleus-javax-persistence
  (package
    (name "java-datanucleus-javax-persistence")
    (version "2.2.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/datanucleus/"
                                  "javax.persistence/archive/javax.persistence-"
                                  version "-release.tar.gz"))
              (sha256
               (base32
                "11jx0fjwgc2hhbqqgdd6m1pf2fplf9vslppygax0y1z5csnqjhpx"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "java-datanucleus-javax-persistence.jar"
       #:jdk ,icedtea-8
       #:source-dir "src/main/java"
       #:tests? #f)); no tests
    (home-page "https://github.com/datanucleus/javax.persistence")
    (synopsis "JPA API")
    (description "This package contains a clean definition of JPA API intended
for use with DataNucleus JPA since the JCP haven't provided an official JPA API
jar.  See @url{http://java.net/projects/jpa-spec/downloads} for the specification
used to generate this API.")
    (license (list license:edl1.0 license:epl1.0))))

(define-public java-osgi-cmpn
  (package
    (name "java-osgi-cmpn")
    (version "6.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/"
                                  "org/osgi/osgi.cmpn/" version "/osgi.cmpn-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1lmb6xyrmkqdhv1kayf0514rlwq6ypvs4m44ibrck3snp8241wys"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-cmpn.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)
       ("core" ,java-osgi-core)
       ("java-datanucleus-javax-persistence" ,java-datanucleus-javax-persistence)
       ("microemulator" ,java-microemulator-cldc)
       ("servlet" ,java-classpathx-servletapi)))
    (home-page "http://www.osgi.org")
    (synopsis "Compendium specification module of OSGi framework")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the compendium specification module, providing interfaces and classes for use
in compiling bundles.")
    (license license:asl2.0)))

(define-public java-osgi-service-component-annotations
  (package
    (name "java-osgi-service-component-annotations")
    (version "1.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.service.component.annotations/"
                                  version "/org.osgi.service.component.annotations-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "15rq9cmp4fpn74q44m4j35qsqmjf5lx3hcrk6pzvbhc08igic2f0"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-service-component-annotations.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)))
    (home-page "http://www.osgi.org")
    (synopsis "Support annotations for osgi-service-component")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the support annotations for osgi-service-component.")
    (license license:asl2.0)))

(define-public java-osgi-dto
  (package
    (name "java-osgi-dto")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.dto/" version "/org.osgi.dto-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0f4bqjzadn0hwk6sd3h5gvbyfp3yci1s6r0v770cc15p0pg627yr"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-dto.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)))
    (home-page "http://www.osgi.org")
    (synopsis "Data Transfer Objects")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the Data Transfer Objects.  It is easily serializable having only public fields
of primitive types and their wrapper classes, Strings, and DTOs.  List, Set,
Map and array aggregates may also be used.  The aggregates must only hold
objects of the listed types or aggregates.")
    (license license:asl2.0)))

(define-public java-osgi-resource
  (package
    (name "java-osgi-resource")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.resource/"
                                  version "/org.osgi.resource-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0hi0fsc5v99q22bd7lrkvpz1y0ds4w9arjldpwsrcpqvz2js7q2d"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-resource.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)
       ("dto" ,java-osgi-dto)))
    (home-page "http://www.osgi.org")
    (synopsis "OSGI Resource")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the definition of common types in osgi packages.")
    (license license:asl2.0)))

(define-public java-osgi-namespace-contract
  (package
    (name "java-osgi-namespace-contract")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.namespace.contract/"
                                  version "/org.osgi.namespace.contract-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1iz4f2i0fvqrlq90ki9nfzcfpvy2av434ri25bglywqssx8mmp36"))))
    (build-system ant-build-system)
    (inputs
     `(("resource" ,java-osgi-resource)
       ("annotation" ,java-osgi-annotation)))
    (arguments
     `(#:jar-name "osgi-namespace-contract.jar"
       #:tests? #f)); no tests
    (home-page "http://www.osgi.org")
    (synopsis "Contract Capability and Requirement Namespace")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the names for the attributes and directives for a namespace with contracts.")
    (license license:asl2.0)))

(define-public java-osgi-namespace-extender
  (package
    (name "java-osgi-namespace-extender")
    (version "1.0.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.namespace.extender/"
                                  version "/org.osgi.namespace.extender-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0jgqiak2i05qv6j3gd33xlaifzzc0ylxxk376v2x0apfg3vvixmz"))))
    (build-system ant-build-system)
    (inputs
     `(("resource" ,java-osgi-resource)
       ("annotation" ,java-osgi-annotation)))
    (arguments
     `(#:jar-name "osgi-namespace-extendent.jar"
       #:tests? #f)); no tests
    (home-page "http://www.osgi.org")
    (synopsis "Extender Capability and Requirement Namespace")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the names for the attributes and directives for an extender namespace.")
    (license license:asl2.0)))

(define-public java-osgi-namespace-service
  (package
    (name "java-osgi-namespace-service")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.namespace.service/"
                                  version "/org.osgi.namespace.service-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0qmw8n2449nkmm56d1znz9zhazb6ya3vsimd5bf5jg23zzhgl8c8"))))
    (build-system ant-build-system)
    (inputs
     `(("resource" ,java-osgi-resource)
       ("annotation" ,java-osgi-annotation)))
    (arguments
     `(#:jar-name "osgi-namespace-service.jar"
       #:tests? #f)); no tests
    (home-page "http://www.osgi.org")
    (synopsis "Service Capability and Requirement Namespace")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the names for the attributes and directives for a service namespace.")
    (license license:asl2.0)))

(define-public java-osgi-util-function
  (package
    (name "java-osgi-util-function")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.util.function/"
                                  version "/org.osgi.util.function-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "04l7j3hwmmj28w23m7paca0afzncs42j2mdr3liqq8kvp548sc6x"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-util-function.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)))
    (home-page "http://www.osgi.org")
    (synopsis "OSGI Util Function")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
an interface for a function that accepts a single argument and produces a result.")
    (license license:asl2.0)))

(define-public java-osgi-util-promise
  (package
    (name "java-osgi-util-promise")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.util.promise/"
                                  version "/org.osgi.util.promise-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0y34dwiflg1c4ahvkswpf9z02xph2sr9fm04ia5493x3lshpw22c"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-util-promise.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)
       ("function" ,java-osgi-util-function)))
    (home-page "http://www.osgi.org")
    (synopsis "Promise of a value")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
an interface and utilitary classes for promises.  A Promise represents a future
value.  It handles the interactions for asynchronous processing.")
    (license license:asl2.0)))

(define-public java-osgi-service-metatype-annotations
  (package
    (name "java-osgi-service-metatype-annotations")
    (version "1.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.service.metatype.annotations/"
                                  version "/org.osgi.service.metatype.annotations-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "12rwm3349wk80vm88rcdgs4435m4jxkpkj5mrx326skkz2c6hyw6"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-service-metatype-annotations.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)))
    (home-page "http://www.osgi.org")
    (synopsis "Support annotations for metatype")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the support annotations for metatype.")
    (license license:asl2.0)))

(define-public java-osgi-service-repository
  (package
    (name "java-osgi-service-repository")
    (version "1.1.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.service.repository/"
                                  version "/org.osgi.service.repository-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1k41mhg7b58pd8nsghr2qwcjrxdnf1p9spsw9v11k4257g6rl06n"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-service-repository.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)
       ("promise" ,java-osgi-util-promise)
       ("resource" ,java-osgi-resource)))
    (home-page "http://www.osgi.org")
    (synopsis "OSGI service repository")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
a repository service that contains resources.")
    (license license:asl2.0)))

(define-public java-osgi-framework
  (package
    (name "java-osgi-framework")
    (version "1.8.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.framework/" version "/org.osgi.framework-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1lwp2zfad3rybcc6q9bwz8xsgkc92ypzy5p6x54387f1qj65m73s"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-framework.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)
       ("resource" ,java-osgi-resource)
       ("dto" ,java-osgi-dto)))
    (home-page "http://www.osgi.org")
    (synopsis "OSGi framework")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.")
    (license license:asl2.0)))

(define-public java-osgi-service-log
  (package
    (name "java-osgi-service-log")
    (version "1.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.service.log/"
                                  version "/org.osgi.service.log-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1029j30dzcwializzca0j3fkhwwz08kmmsha5agw1iccscimj6r0"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-service-log.jar"
       #:tests? #f)); no tests
    (inputs
     `(("java-osgi-framework" ,java-osgi-framework)))
    (home-page "http://www.osgi.org")
    (synopsis "Provides methods for bundles to write messages to the log")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the log service.")
    (license license:asl2.0)))

(define-public java-osgi-service-jdbc
  (package
    (name "java-osgi-service-jdbc")
    (version "1.0.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.service.jdbc/"
                                  version "/org.osgi.service.jdbc-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "11iln5v7bk469cgb9ddkrz9sa95b3733gqgaqw9xf5g6wq652yjz"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-service-jdbc.jar"
       #:tests? #f)); no tests
    (home-page "http://www.osgi.org")
    (synopsis "Factory for JDBC connection factories")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
a factory for JDBC connection factories.  There are 3 preferred connection
factories for getting JDBC connections:

@itemize
@item @code{javax.sql.DataSource};
@item @code{javax.sql.ConnectionPoolDataSource};
@item @code{javax.sql.XADataSource}.
@end itemize")
    (license license:asl2.0)))

(define-public java-osgi-service-resolver
  (package
    (name "java-osgi-service-resolver")
    (version "1.0.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.service.resolver/"
                                  version "/org.osgi.service.resolver-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1dzqn1ryfi2rq4zwsgp44bmj2wlfydjg1qbxw2b0z4xdjjy55vxd"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-service-resolver.jar"
       #:tests? #f)); no tests
    (inputs
     `(("annotation" ,java-osgi-annotation)
       ("resource" ,java-osgi-resource)))
    (home-page "http://www.osgi.org")
    (synopsis "OSGI Resolver service")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
a resolver service that resolves the specified resources in the context supplied
by the caller.")
    (license license:asl2.0)))

(define-public java-osgi-util-tracker
  (package
    (name "java-osgi-util-tracker")
    (version "1.5.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.util.tracker/"
                                  version "/org.osgi.util.tracker-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "0c4fh9vxwzsx59r8dygda0gq2gx3z5vfhc3jsphlqwf5w0h403lz"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-util-tracker.jar"
       #:tests? #f)); no tests
    (inputs
     `(("framework" ,java-osgi-framework)
       ("annotation" ,java-osgi-annotation)))
    (home-page "http://www.osgi.org")
    (synopsis "Bundle tracking")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
bundle tracking utility classes.")
    (license license:asl2.0)))

(define-public java-osgi-service-cm
  (package
    (name "java-osgi-service-cm")
    (version "1.5.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.service.cm/"
                                  version "/org.osgi.service.cm-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "1z8kap48y3xi0ggj8v6czglfnpnd94mmismgi2wbqhj1nl5fzbp6"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-service-cm.jar"
       #:tests? #f)); no tests
    (inputs
     `(("framework" ,java-osgi-framework)
       ("annotation" ,java-osgi-annotation)))
    (home-page "http://www.osgi.org")
    (synopsis "OSGI Configuration Management")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
utility classes for the configuration of services.")
    (license license:asl2.0)))

(define-public java-osgi-service-packageadmin
  (package
    (name "java-osgi-service-packageadmin")
    (version "1.2.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://central.maven.org/maven2/org/osgi/"
                                  "org.osgi.service.packageadmin/"
                                  version "/org.osgi.service.packageadmin-"
                                  version "-sources.jar"))
              (sha256
               (base32
                "041mpxzi7g36wmcily6y4ccn3jx15akpdy8gmhyb7m98x7qfvn52"))))
    (build-system ant-build-system)
    (arguments
     `(#:jar-name "osgi-service-packageadmin.jar"
       #:tests? #f)); no tests
    (inputs
     `(("framework" ,java-osgi-framework)))
    (home-page "http://www.osgi.org")
    (synopsis "OSGI Package Administration")
    (description
      "OSGi, for Open Services Gateway initiative framework, is a module system
and service platform for the Java programming language.  This package contains
the packageadmin service.")
    (license license:asl2.0)))
