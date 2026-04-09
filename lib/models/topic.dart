class Topic {
  final String id;
  final String name;
  final String? parentId;
  final String emoji;
  List<Topic> children;
  final bool isCustom;
  final int depth;

  Topic({
    required this.id,
    required this.name,
    this.parentId,
    required this.emoji,
    List<Topic>? children,
    this.isCustom = false,
    this.depth = 0,
  }) : children = children ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parentId': parentId,
        'emoji': emoji,
        'isCustom': isCustom ? 1 : 0,
      };

  factory Topic.fromMap(Map<String, dynamic> map) => Topic(
        id: map['id'] as String,
        name: map['name'] as String,
        parentId: map['parentId'] as String?,
        emoji: map['emoji'] as String,
        isCustom: (map['isCustom'] as int) == 1,
        // depth is computed at load time, not stored in DB
      );

  @override
  String toString() => '$emoji $name';
}

// ─── ID helpers ───────────────────────────────────────────────────────────────

Topic _t(String id, String name, String emoji, {String? parentId}) => Topic(
      id: id,
      name: name,
      emoji: emoji,
      parentId: parentId,
    );

// ─── Default taxonomy ─────────────────────────────────────────────────────────

final List<Topic> defaultTopics = () {
  // ── PEDIATRICS ──────────────────────────────────────────────────────────────
  final peds = _t('peds', 'Pediatrics', '👶');

  final neo = _t('peds_neo', 'Neonatology', '🍼', parentId: 'peds');
  neo.children = [
    _t('peds_neo_resp', 'Respiratory System', '🫁', parentId: 'peds_neo'),
    _t('peds_neo_card', 'Cardiac', '❤️', parentId: 'peds_neo'),
    _t('peds_neo_neuro', 'Neurology', '🧠', parentId: 'peds_neo'),
    _t('peds_neo_gi', 'Gastrointestinal', '🫃', parentId: 'peds_neo'),
    _t('peds_neo_inf', 'Infections & Sepsis', '🦠', parentId: 'peds_neo'),
    _t('peds_neo_nut', 'Nutrition & Feeding', '🥛', parentId: 'peds_neo'),
    _t('peds_neo_prem', 'Prematurity', '⚖️', parentId: 'peds_neo'),
    _t('peds_neo_jaun', 'Jaundice & Hyperbilirubinemia', '🌡️', parentId: 'peds_neo'),
    _t('peds_neo_proc', 'Procedures & Protocols', '📋', parentId: 'peds_neo'),
    _t('peds_neo_guide', 'Guidelines & References', '📚', parentId: 'peds_neo'),
  ];

  peds.children = [
    neo,
    _t('peds_resp', 'Respiratory', '🫁', parentId: 'peds'),
    _t('peds_card', 'Cardiology', '❤️', parentId: 'peds'),
    _t('peds_neuro', 'Neurology', '🧠', parentId: 'peds'),
    _t('peds_em', 'Emergency Pediatrics', '🚨', parentId: 'peds'),
    _t('peds_inf', 'Infectious Diseases', '🦠', parentId: 'peds'),
    _t('peds_hem', 'Hematology & Oncology', '🩸', parentId: 'peds'),
    _t('peds_endo', 'Endocrinology', '⚗️', parentId: 'peds'),
    _t('peds_dev', 'Developmental Pediatrics', '🌱', parentId: 'peds'),
    _t('peds_nut', 'Nutrition', '🥗', parentId: 'peds'),
    _t('peds_imm', 'Immunization', '💉', parentId: 'peds'),
  ];

  // ── INTERNAL MEDICINE ───────────────────────────────────────────────────────
  final im = _t('im', 'Internal Medicine', '🏥');
  im.children = [
    _t('im_card', 'Cardiology', '❤️', parentId: 'im'),
    _t('im_pulm', 'Pulmonology', '🫁', parentId: 'im'),
    _t('im_gi', 'Gastroenterology', '🫃', parentId: 'im'),
    _t('im_neph', 'Nephrology', '🫘', parentId: 'im'),
    _t('im_endo', 'Endocrinology', '⚗️', parentId: 'im'),
    _t('im_rheum', 'Rheumatology', '🦴', parentId: 'im'),
    _t('im_hem', 'Hematology', '🩸', parentId: 'im'),
    _t('im_inf', 'Infectious Diseases', '🦠', parentId: 'im'),
    _t('im_neuro', 'Neurology', '🧠', parentId: 'im'),
  ];

  // ── SURGERY ─────────────────────────────────────────────────────────────────
  final surg = _t('surg', 'Surgery', '🔪');
  surg.children = [
    _t('surg_gen', 'General Surgery', '⚕️', parentId: 'surg'),
    _t('surg_ortho', 'Orthopedics', '🦴', parentId: 'surg'),
    _t('surg_neuro', 'Neurosurgery', '🧠', parentId: 'surg'),
    _t('surg_card', 'Cardiac Surgery', '❤️', parentId: 'surg'),
    _t('surg_peds', 'Pediatric Surgery', '👶', parentId: 'surg'),
  ];

  // ── OB/GYN ──────────────────────────────────────────────────────────────────
  final obgyn = _t('obgyn', 'Obstetrics & Gynecology', '🤰');
  obgyn.children = [
    _t('obgyn_ob', 'Obstetrics', '🤱', parentId: 'obgyn'),
    _t('obgyn_gyn', 'Gynecology', '⚕️', parentId: 'obgyn'),
    _t('obgyn_fetal', 'Fetal Medicine', '🍼', parentId: 'obgyn'),
    _t('obgyn_mfm', 'Maternal-Fetal Medicine', '💊', parentId: 'obgyn'),
  ];

  // ── EMERGENCY MEDICINE ──────────────────────────────────────────────────────
  final em = _t('em', 'Emergency Medicine', '🚨');
  em.children = [
    _t('em_trauma', 'Trauma', '🩹', parentId: 'em'),
    _t('em_resus', 'Resuscitation', '💓', parentId: 'em'),
    _t('em_tox', 'Toxicology', '☠️', parentId: 'em'),
    _t('em_peds', 'Pediatric Emergency', '👶', parentId: 'em'),
  ];

  // ── PHARMACOLOGY ────────────────────────────────────────────────────────────
  final pharma = _t('pharma', 'Pharmacology', '💊');
  pharma.children = [
    _t('pharma_neo', 'Neonatal Drugs', '🍼', parentId: 'pharma'),
    _t('pharma_peds', 'Pediatric Drugs', '👶', parentId: 'pharma'),
    _t('pharma_abx', 'Antibiotics', '🦠', parentId: 'pharma'),
    _t('pharma_gen', 'General', '💊', parentId: 'pharma'),
  ];

  // ── RESEARCH & GUIDELINES ───────────────────────────────────────────────────
  final research = _t('research', 'Research & Guidelines', '📚');
  research.children = [
    _t('research_who', 'WHO Guidelines', '🌍', parentId: 'research'),
    _t('research_aap', 'AAP Guidelines', '📋', parentId: 'research'),
    _t('research_cochrane', 'Cochrane Reviews', '🔬', parentId: 'research'),
    _t('research_journals', 'Journal Articles', '📰', parentId: 'research'),
    _t('research_books', 'Textbooks', '📖', parentId: 'research'),
    _t('research_cases', 'Case Studies', '🗂️', parentId: 'research'),
  ];

  // ── UNSORTED ────────────────────────────────────────────────────────────────
  final unsorted = _t('unsorted', 'Unsorted', '📥');

  return [peds, im, surg, obgyn, em, pharma, research, unsorted];
}();
