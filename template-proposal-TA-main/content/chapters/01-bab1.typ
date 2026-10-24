// ============================================================
// BAB 1: Pendahuluan
// Disusun berdasarkan kerangka proposal revisi v0.6.2.
// Nilai parameter dan hasil eksperimen tidak diasumsikan telah tersedia.
// ============================================================

= PENDAHULUAN

== Latar Belakang

Pemanfaatan _Large Language Model_ (LLM) pada aplikasi layanan pelanggan memungkinkan
sistem menghasilkan respons terhadap pertanyaan pengguna dalam bahasa alami.
Pada sistem yang menggunakan _Retrieval-Augmented Generation_ (RAG), penyusunan
respons juga melibatkan pengambilan informasi dari basis pengetahuan sebagai
konteks bagi model. Pemrosesan yang dilakukan kembali untuk pertanyaan dengan
jawaban yang sama dapat menambah konsumsi token dan waktu tunggu. Salah satu
pendekatan untuk mengurangi pemrosesan berulang tersebut adalah _semantic response
caching_, yaitu penyimpanan dan penggunaan ulang respons berdasarkan kemiripan
makna pertanyaan. GPTCache merupakan salah satu arsitektur yang menyediakan
mekanisme ini untuk mendukung efisiensi aplikasi berbasis LLM @bang2023gptcache.

Penggunaan ulang respons memerlukan keputusan yang lebih cermat daripada sekadar
menemukan pertanyaan dengan makna yang berdekatan. Dalam penelitian ini, objek
yang dikaji adalah simulasi layanan pelanggan pembayaran digital berbahasa
Indonesia, khususnya pertanyaan mengenai prosedur dan kebijakan yang jawabannya
stabil dalam satu versi basis pengetahuan. Sebagai ilustrasi, pertanyaan
“Transfer belum dikonfirmasi, apakah masih bisa dibatalkan?” dan “Transfer sudah
berhasil, apakah masih bisa dibatalkan?” memiliki susunan kata serta maksud umum
yang berdekatan. Meskipun demikian, perbedaan status transaksi dapat menyebabkan
respons yang berlaku bagi kedua pertanyaan tersebut berbeda menurut kebijakan
layanan. Ilustrasi ini menunjukkan bahwa kemiripan pertanyaan perlu dibedakan
dari validitas penggunaan ulang respons. Kandidat yang tampak mirip, tetapi
responsnya tidak sesuai dengan kondisi pertanyaan baru, merupakan contoh
_hard negative_ dalam pengambilan keputusan _cache_.

Salah satu mekanisme penerimaan respons pada _semantic cache_ adalah penggunaan
ambang kemiripan statis. Respons kandidat diterima apabila skor kemiripannya
memenuhi ambang yang telah ditentukan. Penggunaan satu ambang untuk seluruh
pertanyaan menghadapi kompromi antara kesempatan penggunaan ulang dan risiko
kesalahan. Ambang yang rendah dapat menerima lebih banyak kandidat, termasuk
kandidat yang responsnya tidak valid, sedangkan ambang yang tinggi dapat menolak
parafrasa yang sebenarnya dapat menggunakan respons yang sama. Permasalahan
ambang statis juga menjadi perhatian dalam vCache, yang mempelajari ambang
secara daring untuk setiap pertanyaan tersimpan. Dengan demikian, penyesuaian
ambang secara adaptif telah dikaji dalam penelitian sebelumnya dan tidak
diperlakukan sebagai kebaruan tersendiri dalam penelitian ini
@schroeder2026vcache.

Selain kebijakan ambang, kualitas kandidat dipengaruhi oleh mekanisme pencarian
yang digunakan. Pencarian semantik berbasis representasi vektor dapat
dikombinasikan dengan pencarian leksikal untuk memanfaatkan informasi yang
saling melengkapi. Analisis fungsi penggabungan pada _hybrid retrieval_
menunjukkan pentingnya cara menggabungkan skor serta penanganan skala kedua
sinyal tersebut @bruch2023fusion. Berdasarkan landasan ini, penelitian
direncanakan menggunakan kombinasi kemiripan kosinus antarrepresentasi vektor dan BM25
sebagai skor hibrida. Mekanisme pencarian tersebut menjadi fondasi bersama bagi
seluruh metode ambang yang dibandingkan. Fokus kontribusi penelitian terletak
pada keputusan penerimaan respons setelah satu kandidat dengan skor tertinggi
diperoleh, bukan pada pengembangan fungsi pencarian hibrida yang baru.

Perkembangan penelitian _semantic caching_ memperlihatkan bahwa keputusan
penggunaan ulang dapat dipengaruhi oleh karakteristik yang berbeda. Pendekatan
berbasis kategori mengatur kebijakan _cache_ menurut kategori beban kerja
@wang2025category. ContextCache menggunakan informasi percakapan untuk menangani
kueri multigilir @yan2025contextcache, sedangkan FreshCache mempertimbangkan
risiko keusangan informasi pada RAG berbasis web @mansoor2026freshcache.
Penelitian-penelitian tersebut memberikan konteks bagi perlunya kebijakan
penerimaan yang memperhatikan karakteristik permintaan. Namun, ruang kajian
penelitian ini dibatasi pada pertanyaan satu giliran dengan jawaban stabil,
sehingga perhatian diarahkan pada distribusi skor penggunaan ulang yang tidak
valid di sekitar pertanyaan masuk, bukan pada riwayat percakapan atau perubahan
informasi dari waktu ke waktu.

Hipotesis yang mendasari penelitian ini adalah bahwa distribusi skor kandidat
tidak valid dapat berbeda pada bagian-bagian ruang semantik. Pada sebagian
kelompok pertanyaan, kandidat tidak valid mungkin memiliki skor yang mudah
dipisahkan dari kandidat valid. Pada kelompok lain, perbedaan negasi, angka,
status, atau syarat kebijakan dapat menghasilkan kandidat tidak valid dengan
skor yang tinggi. Apabila perbedaan distribusi tersebut dapat diidentifikasi,
informasi lokal berpotensi membantu penentuan ambang yang lebih sesuai bagi
pertanyaan masuk. Dugaan ini merupakan hipotesis penelitian yang perlu diuji
secara empiris, bukan kesimpulan dari eksperimen yang telah dilakukan.

Untuk menguji hipotesis tersebut, penelitian ini mengusulkan penentuan ambang
adaptif terhadap kueri berbasis _Local Negative Quantile_ (LNQ) pada _hybrid
semantic cache_. Pendekatan ini menggunakan bank kalibrasi yang dibangun secara
luring dari data pengembangan. Setiap titik bank memuat representasi vektor
suatu pertanyaan pengembangan dan skor hibrida tertinggi dari kandidat tidak
valid yang telah diaudit untuk pertanyaan tersebut. Skor ini disebut
_hardest-audited-invalid score_. Istilah tersebut merujuk pada nilai maksimum
dalam cakupan kandidat yang telah diaudit, sehingga tidak dianggap sebagai
nilai maksimum seluruh kandidat tidak valid dalam korpus. Ketika pertanyaan
baru diterima, sistem membentuk lingkungan semantik (_semantic neighborhood_)
dari pertanyaan-pertanyaan kalibrasi yang berdekatan, kemudian menggunakan
kuantil empiris skor tidak valid di lingkungan tersebut sebagai ambang
penerimaan respons.

Bentuk lingkungan semantik yang direncanakan untuk dibandingkan meliputi
_k-nearest neighbors_ (kNN) tanpa penyaring jarak (N1), kNN dengan _far-query
gate_ (N1-G), serta lingkungan berbasis batas kemiripan atau _radius_ (N2).
Kuantil negatif global (B2) digunakan sebagai kontrol untuk memisahkan pengaruh
lokalitas dari penggunaan kuantil itu sendiri. Penelitian juga membandingkan
metode tersebut dengan ambang statis terkalibrasi pada kandidat Top-1 yang
sama. Aturan penggunaan kuantil global sebagai mekanisme pengganti (_fallback_)
ketika syarat lingkungan lokal tidak terpenuhi menjadi bagian dari rancangan
yang turut dievaluasi. Perbandingan ini diperlukan untuk mengetahui apakah
informasi lokal memberikan manfaat tambahan dibandingkan kalibrasi global dan
ambang statis yang dikalibrasi dengan kendala risiko sepadan.

Penggunaan informasi lokal dan kuantil memperoleh landasan konseptual dari
kajian kalibrasi lokal. _Localized conformal prediction_ menekankan informasi
kalibrasi di sekitar titik uji @guan2023localized. Kajian _neighborhood conformal
prediction_ memanfaatkan kedekatan representasi untuk menentukan lingkungan
kalibrasi @ghosh2023neighborhood, sementara kajian pembobotan lokal membahas
hubungan antara lokalitas dan jaminan prediksi @hore2025localweights. Meskipun
memberikan motivasi bagi rancangan LNQ, penelitian ini menggunakan skor
ketidakvalidan penggunaan ulang respons dan tujuan evaluasi _cache_ yang
berbeda. Oleh sebab itu, penggunaan kuantil lokal tidak dengan sendirinya
memberikan jaminan cakupan konformal atau jaminan formal _false positive rate_
(FPR) yang bebas distribusi.

Evaluasi kebijakan penerimaan juga perlu memperhitungkan keseimbangan antara
ketepatan dan pemanfaatan _cache_. Kajian mengenai kesenjangan operasional
_semantic caching_ menekankan bahwa kualitas pemeringkatan belum tentu
mencerminkan manfaat sistem pada ambang penerimaan yang digunakan saat
operasi @baral2026operational. Selain itu, SCALM menunjukkan pentingnya
memperhatikan penghematan token dalam evaluasi _cache_, karena setiap
pertanyaan dapat memiliki kebutuhan pemrosesan yang berbeda @li2024scalm.
Dalam penelitian ini, penerimaan kandidat tidak valid diperlakukan sebagai
kesalahan penggunaan ulang (_false positive reuse_), sehingga tidak diberi
kredit sebagai penghematan token yang valid. Penilaian direncanakan mencakup
FPR, presisi _cache_, tingkat penggunaan ulang yang valid, konsumsi token,
latensi, dan kualitas respons secara menyeluruh. Tambahan waktu komputasi
untuk pencarian lingkungan serta perhitungan kuantil juga diukur agar manfaat
efisiensi dapat dinilai terhadap biayanya.

Agar perbandingan dapat dipertanggungjawabkan, pembentukan bank kalibrasi dan
pemilihan parameter dilakukan menggunakan data pengembangan, sedangkan data
uji terpisah digunakan setelah konfigurasi dibekukan. Pemisahan ini penting
karena pemilihan model atau konfigurasi berdasarkan kinerja pada data yang
sama dapat menimbulkan optimisme pada estimasi kinerja @rink2025postselection.
Kelompok pertanyaan yang saling berkaitan, seperti parafrasa dan pasangan
dengan perbedaan kondisi minimal, perlu diperhatikan dalam pembagian data
serta analisis ketidakpastian. Dengan rancangan tersebut, penelitian ini
diarahkan untuk menghasilkan bukti empiris mengenai manfaat dan keterbatasan
ambang berbasis LNQ dalam menekan penggunaan ulang respons yang keliru sambil
mempertahankan penggunaan ulang yang valid. Keunggulan metode lokal atas
pembanding tetap ditentukan oleh hasil pengujian, termasuk apabila tidak
ditemukan konfigurasi yang memenuhi sasaran risiko dan manfaat yang ditetapkan.

== Rumusan Masalah

#block(sticky: true)[
  Berdasarkan latar belakang tersebut, rumusan masalah dalam penelitian ini
  adalah sebagai berikut:
]

+ Bagaimana membangun bank kalibrasi dari _hardest-audited-invalid score_ dan
  merancang ambang penerimaan berbasis LNQ untuk setiap pertanyaan masuk pada
  _hybrid semantic cache_?
+ Bagaimana menentukan parameter pencarian, kuantil, lingkungan semantik,
  _gate_, dan _fallback_, serta sasaran FPR dan presisi _cache_ menggunakan
  data pengembangan tanpa kebocoran informasi dari data uji?
+ Bagaimana perbandingan LNQ dengan lingkungan N1, N1-G, dan N2 terhadap
  ambang statis terkalibrasi serta kuantil negatif global dalam menyeimbangkan
  kesalahan penggunaan ulang dan penggunaan ulang yang valid pada kandidat
  Top-1 yang sama?
+ Seberapa besar manfaat efisiensi token dan latensi serta tambahan biaya
  komputasi metode yang diusulkan, dan bagaimana kualitas responsnya
  dibandingkan dengan pemrosesan RAG/LLM tanpa _response cache_?

== Batasan Masalah

Untuk menjaga keterarahan penelitian dan memisahkan pengaruh kebijakan ambang
dari komponen sistem lainnya, ruang lingkup penelitian dibatasi sebagai berikut:

+ Penelitian dilakukan pada simulasi layanan pelanggan pembayaran digital
  berbahasa Indonesia. Pertanyaan yang dikaji berhubungan dengan prosedur dan
  pertanyaan yang sering diajukan, dengan jawaban stabil dalam satu versi basis
  pengetahuan. Pembatasan ini digunakan untuk memusatkan evaluasi pada validitas
  penggunaan ulang respons dalam konteks kebijakan yang tetap.
+ Interaksi dibatasi pada satu giliran (_single-turn_). Permintaan yang
  memerlukan saldo, status transaksi waktu nyata, identitas pribadi, atau
  sumber data dinamis tidak diperlakukan sebagai respons yang secara otomatis
  dapat digunakan ulang. Pemeriksaan kelayakannya dilakukan berdasarkan
  informasi yang tersedia saat sistem beroperasi, bukan menggunakan label
  kebenaran dari data evaluasi.
+ Kontribusi utama dibatasi pada pembentukan bank kalibrasi luring dan
  penentuan ambang penerimaan per pertanyaan masuk. Optimasi penggantian
  entri _cache_, pelatihan ulang LLM utama, pembelajaran ambang secara daring,
  dan pemodelan percakapan multigilir berada di luar fokus penelitian.
+ Seluruh metode ambang menggunakan korpus _cache_, aturan kelayakan, model
  representasi, serta fungsi skor hibrida yang sama dalam setiap perbandingan.
  Keputusan penerimaan dilakukan terhadap satu kandidat Top-1 setelah
  penyaringan korpus yang konsisten. Penolakan kandidat tersebut tidak
  dilanjutkan dengan mencoba kandidat peringkat berikutnya, agar pengaruh
  kebijakan ambang dapat dibandingkan pada kandidat yang identik.
+ Korpus _cache_ final direncanakan dikurasi dari basis pengetahuan secara
  independen dari hubungan berlabel antara pertanyaan uji dan kandidat.
  Korpus dibekukan sebelum pertanyaan uji disusun atau dipilih. Data serta
  _cache_ dari eksplorasi awal digunakan untuk studi pendahuluan atau
  pengembangan, bukan sebagai data uji konfirmatori yang dianggap belum
  pernah digunakan.
+ Validitas penggunaan ulang ditentukan berdasarkan kesesuaian respons
  kandidat terhadap kondisi pertanyaan masuk menurut basis pengetahuan atau
  jawaban acuan. Pasangan pertanyaan dan kandidat merupakan unit anotasi,
  sedangkan unit evaluasi keputusan ambang adalah kandidat Top-1 aktual per
  pertanyaan. Skor kalibrasi merupakan maksimum atas kandidat tidak valid yang
  telah diaudit dalam cakupan pencarian yang didokumentasikan. Kandidat
  evaluasi tanpa label tidak dianggap tidak valid dan tidak dihilangkan tanpa
  pelaporan.
+ Pembentukan bank, pemilihan parameter, dan kalibrasi ambang hanya
  menggunakan data pengembangan sesuai pembagian kelompok yang ditetapkan.
  Parafrasa, turunan templat, serta pasangan pertanyaan dengan perbedaan
  kondisi minimal yang saling berkaitan dipertahankan dalam kelompok pembagian
  yang sama. Data uji terpisah digunakan setelah konfigurasi dibekukan untuk
  membatasi kebocoran informasi dan bias pemilihan konfigurasi.
+ Pembanding utama meliputi pemrosesan tanpa _response cache_ (B0), ambang
  statis berdasarkan indeks ROC--Youden (B1-J), ambang statis dengan kendala
  risiko (B1-C), dan kuantil negatif global (B2). Bentuk lokal yang diuji
  meliputi N1, N1-G, dan N2. Kuantil global dengan tingkat kuantil yang sama
  digunakan sebagai _fallback_ utama ketika syarat _gate_ atau dukungan
  lingkungan lokal pada N1-G dan N2 tidak terpenuhi. Bank yang tidak valid
  menyebabkan penggunaan ulang ditolak dan permintaan diteruskan ke jalur
  pemrosesan lengkap.
+ Ukuran data, proporsi pembagian, perangkat implementasi, nilai parameter,
  dan sasaran numerik risiko belum ditetapkan sebagai hasil final dalam
  kerangka penelitian. Penetapannya dilakukan melalui prosedur pengembangan
  yang terdokumentasi sebelum pengujian akhir. Sasaran risiko dijustifikasi
  berdasarkan manfaat dan kerugian penggunaan ulang serta batas kesalahan
  operasional atau skenario risiko. Nilai contoh eksplorasi awal tidak
  diperlakukan sebagai parameter optimal.
+ Kesimpulan dibatasi pada domain, versi basis pengetahuan, model, data, dan
  protokol evaluasi yang digunakan. Efisiensi dinilai dari token dan latensi
  yang benar-benar diukur, termasuk tambahan biaya metode lokal. Skor
  kemiripan tidak dianggap sebagai probabilitas kebenaran, dan LNQ tidak
  diklaim memiliki jaminan formal FPR atau cakupan konformal. Penolakan
  seluruh kandidat tidak dianggap sebagai bukti manfaat sistem karena
  penggunaan ulang yang valid tetap menjadi pertimbangan.

== Tujuan

#block(sticky: true)[
  Penelitian ini bertujuan merancang dan mengevaluasi ambang penerimaan adaptif
  berbasis LNQ pada _hybrid semantic cache_ untuk mengkaji pengendalian
  kesalahan penggunaan ulang respons dan efisiensi inferensi LLM. Tujuan
  khusus penelitian yang bersesuaian dengan rumusan masalah adalah sebagai berikut:
]

+ Merancang dan mengembangkan _hybrid semantic cache_, bank kalibrasi
  luring berbasis _hardest-audited-invalid score_, serta fungsi kuantil
  negatif lokal untuk menghasilkan keputusan penerimaan atau penolakan
  penggunaan ulang respons per pertanyaan masuk.
+ Menyusun prosedur serta menentukan parameter pencarian dan kebijakan
  ambang menggunakan data pengembangan, dengan sasaran FPR dan presisi
  _cache_ yang dijustifikasi dan konfigurasi yang dibekukan sebelum pengujian
  akhir.
+ Membandingkan N1, N1-G, dan N2 dengan ambang statis terkalibrasi serta
  kuantil negatif global pada fondasi pencarian yang sama, disertai analisis
  ablasi untuk mengidentifikasi pengaruh lokalitas, _gate_, dan _fallback_
  terhadap kesalahan serta penggunaan ulang yang valid.
+ Mengukur FPR, presisi _cache_, _valid cache hit ratio_ (VCHR), pemanfaatan
  _cache_, penghematan token yang valid, latensi, tambahan biaya komputasi,
  kualitas respons, serta ketidakpastian hasil pada data uji terpisah dengan
  pemrosesan tanpa _response cache_ sebagai acuan efisiensi dan kualitas.

== Manfaat

Penelitian ini diharapkan memberikan manfaat sebagai berikut:

=== Manfaat Teoritis

+ Menambah bukti empiris mengenai hubungan antara distribusi skor kandidat
  tidak valid pada lingkungan semantik lokal dan kinerja ambang penerimaan
  respons dalam _hybrid semantic cache_.
+ Memberikan pemahaman mengenai perbedaan manfaat lokalitas, mekanisme
  penyaring lingkungan, serta _fallback_ terhadap keseimbangan antara
  kesalahan penggunaan ulang dan penggunaan ulang yang valid melalui
  perbandingan dengan kalibrasi global serta ambang statis.

=== Manfaat Praktis

+ Menyediakan rancangan dan prototipe kebijakan penerimaan respons yang
  dapat dijadikan acuan pengembangan _semantic cache_ pada layanan pelanggan
  dengan jawaban stabil, disertai pencatatan keputusan dan prosedur kalibrasi
  yang dapat ditelusuri.
+ Menyediakan hasil pengukuran yang membantu pengembang mempertimbangkan
  ketepatan respons, penghematan token, latensi, dan tambahan biaya komputasi
  sebelum memilih konfigurasi _cache_ sesuai kebutuhan layanan.

=== Manfaat Sosial

+ Memberikan dasar pertimbangan bagi pengembangan layanan informasi
  pembayaran digital yang lebih berhati-hati dalam menggunakan ulang
  jawaban, khususnya ketika pertanyaan pengguna berbeda pada kondisi yang
  menentukan berlakunya suatu kebijakan.
+ Mendukung upaya penyediaan layanan pelanggan yang responsif dan
  penggunaan sumber daya komputasi yang efisien, sepanjang hasil pengujian
  menunjukkan manfaat tanpa mengabaikan kualitas jawaban bagi pengguna.
