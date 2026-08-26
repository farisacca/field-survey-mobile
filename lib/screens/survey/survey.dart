import 'package:flutter/material.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final _formKey = GlobalKey<FormState>();

  final namaController = TextEditingController();
  final umurController = TextEditingController();
  final alamatController = TextEditingController();
  final keteranganController = TextEditingController();

  String? selectedGender;

  @override
  void dispose() {
    namaController.dispose();
    umurController.dispose();
    alamatController.dispose();
    keteranganController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF7B1E3A);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          "Survey Lapangan",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: true,
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              // =================================================
              // HEADER
              // =================================================

              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(
                  color: primaryColor,

                  borderRadius:
                      BorderRadius.circular(20),

                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),

                child: Row(
                  children: [

                    Container(
                      width: 55,
                      height: 55,

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius:
                            BorderRadius.circular(16),
                      ),

                      child: const Icon(
                        Icons.assignment_outlined,

                        color: primaryColor,

                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 15),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          Text(
                            "Survey Lapangan",

                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 5),

                          Text(
                            "Isi data survey dengan lengkap",

                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // =================================================
              // STATISTIK
              // =================================================

              Row(
                children: [

                  Expanded(
                    child: surveyInfoCard(
                      "Survey Hari Ini",
                      "12",
                      Icons.assignment,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: surveyInfoCard(
                      "Survey Selesai",
                      "10",
                      Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // =================================================
              // JUDUL DATA SURVEY
              // =================================================

              const Text(
                "Data Survey",

                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Masukkan informasi yang diperoleh saat melakukan survey lapangan.",

                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // NAMA
              // =================================================

              TextFormField(
                controller: namaController,

                decoration: inputDecoration(
                  "Nama Lengkap",
                  Icons.person_outline,
                ),

                validator: (value) {
                  if (value == null ||
                      value.isEmpty) {
                    return "Nama harus diisi";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // UMUR
              // =================================================

              TextFormField(
                controller: umurController,

                keyboardType:
                    TextInputType.number,

                decoration: inputDecoration(
                  "Umur",
                  Icons.cake_outlined,
                ),

                validator: (value) {
                  if (value == null ||
                      value.isEmpty) {
                    return "Umur harus diisi";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // JENIS KELAMIN
              // =================================================

              DropdownButtonFormField<String>(
                initialValue: selectedGender,

                decoration: inputDecoration(
                  "Jenis Kelamin",
                  Icons.people_outline,
                ),

                items: const [

                  DropdownMenuItem(
                    value: "Laki-laki",
                    child: Text("Laki-laki"),
                  ),

                  DropdownMenuItem(
                    value: "Perempuan",
                    child: Text("Perempuan"),
                  ),
                ],

                onChanged: (value) {
                  setState(() {
                    selectedGender = value;
                  });
                },

                validator: (value) {
                  if (value == null) {
                    return "Pilih jenis kelamin";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // ALAMAT
              // =================================================

              TextFormField(
                controller: alamatController,

                maxLines: 3,

                decoration: inputDecoration(
                  "Alamat / Lokasi Survey",
                  Icons.location_on_outlined,
                ),

                validator: (value) {
                  if (value == null ||
                      value.isEmpty) {
                    return "Alamat harus diisi";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 18),

              // =================================================
              // KETERANGAN
              // =================================================

              TextFormField(
                controller:
                    keteranganController,

                maxLines: 4,

                decoration: inputDecoration(
                  "Hasil / Keterangan Survey",
                  Icons.description_outlined,
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // BUTTON SIMPAN
              // =================================================

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton.icon(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        primaryColor,

                    foregroundColor:
                        Colors.white,

                    elevation: 4,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),

                  icon: const Icon(
                    Icons.save_outlined,
                  ),

                  label: const Text(
                    "Simpan Survey",

                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  onPressed: () {

                    if (_formKey.currentState!
                        .validate()) {

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Data survey berhasil disimpan",
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // INPUT DECORATION
  // =========================================================

  InputDecoration inputDecoration(
    String hint,
    IconData icon,
  ) {
    const Color primaryColor =
        Color(0xFF7B1E3A);

    return InputDecoration(
      hintText: hint,

      prefixIcon: Icon(
        icon,
        color: primaryColor,
      ),

      filled: true,

      fillColor: Colors.white,

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(15),

        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(15),

        borderSide: const BorderSide(
          color: Color(0xFFE5E5E5),
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(15),

        borderSide: const BorderSide(
          color: primaryColor,
          width: 2,
        ),
      ),
    );
  }

  // =========================================================
  // SURVEY INFO CARD
  // =========================================================

  Widget surveyInfoCard(
    String title,
    String value,
    IconData icon,
  ) {
    const Color primaryColor =
        Color(0xFF7B1E3A);

    return Card(
      elevation: 4,

      shadowColor: Colors.black12,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(18),

        child: Column(
          children: [

            CircleAvatar(
              radius: 21,

              backgroundColor:
                  const Color(0xFFF7E7EB),

              child: Icon(
                icon,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              value,

              style: const TextStyle(
                color: primaryColor,
                fontSize: 23,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              title,

              textAlign:
                  TextAlign.center,

              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}