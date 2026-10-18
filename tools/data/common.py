"""問題データ定義の共通部品"""
from dataclasses import dataclass, field


@dataclass
class Question:
    category: str
    difficulty: int
    text: str
    choices: list
    explanation: str
    fixed: bool = False


@dataclass
class Term:
    category: str
    term: str
    reading: str
    definition: str


def Q(category, difficulty, text, answer, w1, w2, w3, explanation, fixed=False):
    """正解を先頭に書く。並べ替えはビルドスクリプトで行う。"""
    return Question(category, difficulty, text, [answer, w1, w2, w3], explanation, fixed)


def T(category, term, reading, definition):
    return Term(category, term, reading, definition)


# 中分類（シラバスの区分）
CATEGORIES = [
    # (id, 大分類, 名前, SF Symbol)
    ("corp", "strategy", "企業活動", "building.2"),
    ("law", "strategy", "法務", "scale.3d"),
    ("mgmt_strategy", "strategy", "経営戦略", "chart.pie"),
    ("tech_strategy", "strategy", "技術戦略", "lightbulb"),
    ("industry", "strategy", "ビジネスインダストリ", "cart"),
    ("sys_strategy", "strategy", "システム戦略", "square.stack.3d.up"),
    ("sys_plan", "strategy", "システム企画", "doc.text.magnifyingglass"),
    ("dev", "management", "開発技術", "hammer"),
    ("pm", "management", "プロジェクトマネジメント", "calendar.badge.clock"),
    ("sm", "management", "サービスマネジメント", "headphones"),
    ("audit", "management", "システム監査", "checkmark.seal"),
    ("theory", "technology", "基礎理論・AI", "function"),
    ("algo", "technology", "アルゴリズム", "arrow.triangle.branch"),
    ("component", "technology", "コンピュータ構成要素", "cpu"),
    ("system", "technology", "システム構成要素", "server.rack"),
    ("software", "technology", "ソフトウェア", "macwindow"),
    ("hardware", "technology", "ハードウェア", "iphone"),
    ("design", "technology", "情報デザイン", "paintpalette"),
    ("media", "technology", "情報メディア", "photo"),
    ("db", "technology", "データベース", "cylinder.split.1x2"),
    ("network", "technology", "ネットワーク", "network"),
    ("security", "technology", "セキュリティ", "lock.shield"),
]
