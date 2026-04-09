/// Complete medical specialty taxonomy used to pre-populate MedShelf folders.
///
/// Keys   → specialty name + emoji (e.g. "Anatomy 🦴")
/// Values → list of topic names + emoji for that specialty
const Map<String, List<String>> medicalSpecialties = {
  // ── Pre-clinical ────────────────────────────────────────────────────────────

  'Anatomy 🦴': [
    'General Anatomy 🦴', 'Embryology 👶', 'Histology 🔬', 'Genetics 🧬',
    'Upper Limb 💪', 'Lower Limb 🦵', 'Thorax 🫀', 'Abdomen 🍽️',
    'Pelvis & Perineum ⚙️', 'Head & Neck 🧠', 'Neuroanatomy 🔌',
    'Surface Anatomy 🧍', 'Radiological Anatomy 🩻',
  ],
  'Physiology ⚙️': [
    'General Physiology ⚙️', 'Cell Physiology 🧫', 'Blood 🩸',
    'Nerve & Muscle 🔌', 'Cardiovascular System ❤️', 'Respiratory System 🌬️',
    'Gastrointestinal System 🍽️', 'Renal System 🚰', 'Endocrine System 🧪',
    'Reproductive System ♀️', 'Central Nervous System 🧠',
    'Special Senses 👁️', 'Exercise Physiology 🏃',
  ],
  'Biochemistry 🧬': [
    'General Biochemistry 🧬', 'Cell & Molecular Biology 🧫', 'Enzymes ⚡',
    'Bioenergetics 🔋', 'Carbohydrate Metabolism 🍞',
    'Protein & Amino Acid Metabolism 🍗', 'Lipid Metabolism 🧈',
    'Nucleotide Metabolism 🔬', 'Molecular Genetics 🔭', 'Vitamins 🍊',
    'Minerals & Trace Elements ⚗️', 'Nutrition 🍎', 'Hormones 🧪',
    'Clinical Biochemistry 📋', 'Detoxification 🧼',
  ],
  'Pathology 🔍': [
    'Cell Injury & Adaptation ⚠️', 'Inflammation 🔥',
    'Hemodynamic Disorders 🩸', 'Neoplasia 🎯', 'Immunopathology 🛡️',
    'Genetic Disorders 🧬', 'Hematology 🩸', 'Cardiovascular Pathology ❤️',
    'Respiratory Pathology 🌬️', 'Gastrointestinal Pathology 🍽️',
    'Hepatobiliary & Pancreatic Pathology 🫀', 'Renal Pathology 🚰',
    'Endocrine Pathology 🧪', 'Reproductive Pathology ♀️',
    'Breast Pathology 🎗️', 'Neuropathology 🧠',
    'Musculoskeletal Pathology 🦴', 'Skin Pathology 🧴',
  ],
  'Pharmacology 💊': [
    'General Pharmacology ⚙️', 'Pharmacokinetics & Pharmacodynamics 📊',
    'Autonomic Nervous System 🧠', 'Cardiovascular Drugs ❤️',
    'Central Nervous System Drugs 💊', 'Respiratory Drugs 🌬️',
    'Gastrointestinal Drugs 🍽️', 'Endocrine Drugs 🧪', 'Renal Drugs 🚰',
    'Blood & Hematopoietic Drugs 🩸', 'Chemotherapy ⚔️',
    'Antimicrobials 🦠', 'Antitubercular & Antileprosy Drugs 🫁',
    'Anticancer Drugs 🎯', 'Immunopharmacology 🛡️', 'Toxicology ☠️',
    'Clinical Pharmacology 📋',
  ],
  'Microbiology 🦠': [
    'General Microbiology 🔬', 'Sterilization & Disinfection 🧼',
    'Immunology 🛡️', 'Hypersensitivity ⚠️', 'Vaccines 💉',
    'Bacteriology 🧫', 'Gram Positive Cocci 🔵', 'Gram Negative Cocci 🔴',
    'Gram Positive Bacilli 🟣', 'Gram Negative Bacilli 🟤',
    'Mycobacteria 🫁', 'Spirochetes 🌀', 'Virology 🧬',
    'DNA Viruses 🔬', 'RNA Viruses 🔭', 'Mycology 🍄',
    'Parasitology 🪱', 'Protozoa 🦠', 'Helminths 🪱',
    'Applied Microbiology 🏥',
  ],
  'Forensic Medicine ⚖️': [
    'Legal Procedures 📜', 'Medical Ethics ⚖️', 'Identification 🪪',
    'Thanatology 💀', 'Postmortem Changes 🔍', 'Injuries ⚔️',
    'Mechanical Injuries 🔧', 'Thermal Injuries 🔥', 'Asphyxia 😵',
    'Toxicology ☠️', 'Poisoning 🧪', 'Alcohol & Drugs 🍷',
    'Sexual Offences 🚫', 'Infanticide 🚫', 'Medicolegal Aspects 📋',
  ],
  'Community Medicine 🌍': [
    'Epidemiology 📊', 'Biostatistics 📈', 'Screening & Surveillance 🔎',
    'Communicable Diseases 🦠', 'Non-Communicable Diseases 🏥',
    'Nutrition 🍎', 'Environmental Health 🌱', 'Occupational Health 👷',
    'Demography 👥', 'Health Indicators 📊', 'National Health Programs 🏥',
    'Health Management 📋', 'Health Education 📢', 'International Health 🌐',
  ],

  // ── Clinical ────────────────────────────────────────────────────────────────

  'General Medicine 🩺': [
    'Clinical Methods 🩺', 'Cardiology ❤️', 'Hypertension 📈',
    'Respiratory Medicine 🌬️', 'Gastroenterology 🍽️', 'Hepatology 🫀',
    'Nephrology 🚰', 'Neurology 🧠', 'Endocrinology 🧪', 'Diabetes 💉',
    'Hematology 🩸', 'Oncology 🎯', 'Infectious Diseases 🦠',
    'Tropical Diseases 🌴', 'Rheumatology 🦴',
    'Dermatology (Medicine aspect) 🧴', 'Emergency Medicine 🚨',
    'Geriatrics 👴',
  ],
  'Dermatology 🧴': [
    'Structure & Function of Skin 🧴', 'Infections 🦠', 'Bacterial 🧫',
    'Viral 🧬', 'Fungal 🍄', 'Parasitic 🪱', 'Eczema & Dermatitis 🔴',
    'Papulosquamous Disorders 📋', 'Vesiculobullous Disorders 💧',
    'Pigmentary Disorders 🎨', 'Hair Disorders 💇', 'Nail Disorders 💅',
    'Sexually Transmitted Diseases 🚫', 'Leprosy 🏥',
  ],
  'Psychiatry 🧠': [
    'General Psychiatry 🧠', 'Mental Status Examination 📋',
    'Schizophrenia 🔮', 'Mood Disorders 😢', 'Anxiety Disorders 😰',
    'OCD 🔄', 'Substance Use Disorders 🍷', 'Personality Disorders 🧩',
    'Organic Psychiatry 🔬', 'Child Psychiatry 👶', 'Psychotherapy 🗣️',
  ],
  'Pediatrics 👶': [
    'Genetics & Syndromes 🧬', 'Metabolic Disorders ⚡',
    'Immunity / Fluids / Electrolytes / Drugs 🛡️', 'Emergency (PICU) 🚨',
    'Emergency (NICU) 🏥',
    'Growth / Development / Behaviour / Adolescence 📏',
    'Nutrition & Its Disorders 🍎', 'Immunisation 💉',
    'Infectious Diseases 🦠', 'Gastrointestinal Disorders 🍽️',
    'Haematology & Oncology 🩸', 'Respiratory Diseases 🌬️',
    'Cardiovascular Diseases ❤️', 'Renal / Urinary Disorders 🚰',
    'Neurology 🧠', 'Rheumatology 🦴', 'Endocrinology 🧪',
    'Eye / Skin / Bone 👁️', 'Social Pediatrics 🌍',
  ],
  'Neonatology 🍼': [
    'Fetal Physiology & Transition 👶', 'Neonatal Resuscitation ❤️',
    'Thermoregulation 🌡️', 'Fluids & Nutrition 💧',
    'Preterm & High-Risk Neonates ⚠️', 'Respiratory Disorders 🌬️',
    'Cardiovascular Disorders ❤️', 'Neonatal Sepsis & Infections 🦠',
    'Neonatal Jaundice 🟡', 'Neurology (HIE Seizures) 🧠',
    'Metabolic Disorders ⚡', 'Gastrointestinal Disorders 🍽️',
    'Hematology 🩸', 'Renal & Electrolytes 🚰',
    'Congenital Anomalies 🧬', 'ROP & Hearing 👁️',
    'Procedures & NICU Care 🏥', 'Follow-up & Development 📏',
    'Transport & Ethics 🚑',
  ],
  'General Surgery 🔪': [
    'Surgical Principles ⚙️', 'Wound Healing 🩹', 'Shock ⚠️',
    'Trauma 🚑', 'Burns 🔥', 'Surgical Infections 🦠',
    'Fluid & Electrolyte Balance 💧', 'Gastrointestinal Surgery 🍽️',
    'Esophagus 🌊', 'Stomach 🍽️', 'Small Intestine 🌀',
    'Large Intestine 🔄', 'Hepatobiliary Surgery 🫀', 'Pancreas ⚙️',
    'Colorectal Surgery 🔪', 'Hernia ⚠️', 'Breast 🎗️', 'Thyroid 🦋',
    'Urology 🚻', 'Vascular Surgery 🩸', 'Minimal Access Surgery 🎥',
  ],
  'Orthopedics 🦴': [
    'General Orthopedics ⚙️', 'Fracture Healing 🩹', 'Fractures 🦴',
    'Dislocations ⚙️', 'Bone Tumors 🎯', 'Infections 🦠',
    'Osteomyelitis 🔥', 'Tuberculosis 🫁', 'Spine Disorders 🧱',
    'Joint Disorders ⚙️', 'Arthritis 🔥', 'Pediatric Orthopedics 👶',
    'Congenital Disorders 🧬',
  ],
  'Anesthesia 😴': [
    'Preoperative Assessment 📋', 'General Anesthesia 😴',
    'Regional Anesthesia 💉', 'Local Anesthesia 💊',
    'Airway Management 🌬️', 'Ventilation 💨', 'Monitoring 📡',
    'Pain Management 😖', 'ICU Care 🏥',
  ],
  'Radiology 📡': [
    'Imaging Principles ⚛️', 'X-ray 🩻', 'Ultrasound 🔊', 'CT 📊',
    'MRI 🧲', 'Nuclear Medicine ⚛️', 'Interventional Radiology 💉',
    'Contrast Media 🧪', 'Radiation Safety ☢️',
  ],
  'Obstetrics & Gynecology 🤰': [
    'Anatomy & Physiology ⚙️', 'Normal Pregnancy 🤰',
    'Antenatal Care 📋', 'Fetal Development 👶', 'Labour 🔄',
    'Puerperium 🛌', 'High-Risk Pregnancy ⚠️',
    'Obstetric Emergencies 🚨', 'Contraception 🛑',
    'Menstrual Disorders 🔄', 'Infertility 🔬',
    'Gynecological Infections 🦠', 'Pelvic Floor Disorders 🦴',
    'Benign Gynecological Conditions 📋',
    'Gynecological Malignancies 🎯',
  ],
  'Ophthalmology 👁️': [
    'Anatomy & Physiology of Eye 👁️', 'Refraction 🔎', 'Cataract 🔍',
    'Glaucoma ⚡', 'Cornea 🔵', 'Uvea 🌈', 'Retina 📸',
    'Optic Nerve 🔌', 'Neuro-ophthalmology 🧠', 'Ocular Trauma ⚠️',
  ],
  'ENT 👂': [
    'Ear 👂', 'External Ear 👂', 'Middle Ear 🔊', 'Inner Ear ⚖️',
    'Nose 👃', 'Paranasal Sinuses 🕳️', 'Throat 🗣️', 'Larynx 🎤',
    'Pharynx 🍽️', 'Head & Neck 🧠', 'Audiology 📈',
    'Vestibular Disorders ⚖️',
  ],
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Extracts the trailing emoji from a combined name+emoji string.
/// e.g. `"Anatomy 🦴"` → `"🦴"`
String extractEmoji(String nameWithEmoji) {
  final parts = nameWithEmoji.trim().split(' ');
  return parts.last;
}

/// Extracts the name portion (without the trailing emoji).
/// e.g. `"Anatomy 🦴"` → `"Anatomy"`
String extractName(String nameWithEmoji) {
  final parts = nameWithEmoji.trim().split(' ');
  parts.removeLast();
  return parts.join(' ');
}
