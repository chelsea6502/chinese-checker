"""
Chinese Checker - Streamlit Web Application

A web interface for analyzing Chinese text comprehension based on known words.
"""

import streamlit as st
import tempfile
import os
from script import comprehension_checker, KNOWN_WORDS_DIR, UNKNOWN_WORDS_DIR
from typing import List

# Page configuration
st.set_page_config(
    page_title="Chinese Checker",
    page_icon="📚",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        margin-bottom: 0.5rem;
    }
    .sub-header {
        font-size: 1.2rem;
        color: #666;
        margin-bottom: 2rem;
    }
    .result-box {
        background-color: #f0f2f6;
        padding: 1.5rem;
        border-radius: 0.5rem;
        margin: 1rem 0;
    }
    .stTabs [data-baseweb="tab-list"] {
        gap: 2rem;
    }
</style>
""", unsafe_allow_html=True)

def load_word_list(directory: str) -> List[str]:
    """Load all words from txt files in a directory."""
    words = []
    if os.path.exists(directory) and os.path.isdir(directory):
        for filename in os.listdir(directory):
            if filename.endswith('.txt'):
                filepath = os.path.join(directory, filename)
                with open(filepath, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#'):
                            word = line.split('\t')[0].split('#')[0].strip()
                            if word:
                                words.append(word)
    return words

def save_word_list(directory: str, filename: str, words: List[str]):
    """Save words to a file in the specified directory."""
    os.makedirs(directory, exist_ok=True)
    filepath = os.path.join(directory, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        for word in words:
            f.write(f"{word}\n")

def main():
    # Header
    st.markdown('<div class="main-header">📚 Chinese Checker</div>', unsafe_allow_html=True)
    st.markdown('<div class="sub-header">Analyze Chinese text comprehension based on your known words</div>', unsafe_allow_html=True)
    
    # Sidebar for word management
    with st.sidebar:
        st.header("⚙️ Settings")
        
        # Known words management
        with st.expander("📖 Manage Known Words", expanded=False):
            st.markdown("Add words you know (one per line):")
            known_words = load_word_list(KNOWN_WORDS_DIR)
            known_text = st.text_area(
                "Known Words",
                value="\n".join(known_words),
                height=200,
                key="known_words",
                label_visibility="collapsed"
            )
            
            col1, col2 = st.columns(2)
            with col1:
                if st.button("💾 Save Known", use_container_width=True, key="save_known"):
                    words = [w.strip() for w in known_text.split('\n') if w.strip()]
                    save_word_list(KNOWN_WORDS_DIR, "words.txt", words)
                    st.success(f"Saved {len(words)} words!")
            with col2:
                if st.button("🔄 Reset", use_container_width=True, key="reset_known"):
                    st.rerun()
        
        # Unknown words management
        with st.expander("❌ Manage Unknown Words", expanded=False):
            st.markdown("Add compound words that shouldn't count as known:")
            unknown_words = load_word_list(UNKNOWN_WORDS_DIR)
            unknown_text = st.text_area(
                "Unknown Words",
                value="\n".join(unknown_words),
                height=150,
                key="unknown_words",
                label_visibility="collapsed"
            )
            
            col1, col2 = st.columns(2)
            with col1:
                if st.button("💾 Save Unknown", use_container_width=True, key="save_unknown"):
                    words = [w.strip() for w in unknown_text.split('\n') if w.strip()]
                    save_word_list(UNKNOWN_WORDS_DIR, "compounds.txt", words)
                    st.success(f"Saved {len(words)} words!")
            with col2:
                if st.button("🔄 Reset", use_container_width=True, key="reset_unknown"):
                    st.rerun()
        
        st.divider()
        
        # Info section
        st.markdown("### ℹ️ About")
        st.markdown("""
        This tool analyzes Chinese text to calculate your comprehension percentage based on known words.
        
        **Features:**
        - 📊 Comprehension analysis
        - 🔤 Pinyin for unknown words
        - 📖 Dictionary definitions
        - 🎯 Proper noun detection
        """)
        
        st.markdown("---")
        st.markdown("Built with ❤️ using [Streamlit](https://streamlit.io)")
    
    # Main content area with tabs
    tab1, tab2 = st.tabs(["📝 Analyze Text", "📁 Upload Files"])
    
    with tab1:
        st.markdown("### Paste Chinese Text")
        text_input = st.text_area(
            "Enter Chinese text to analyze:",
            height=300,
            placeholder="粘贴中文文本在这里...",
            label_visibility="collapsed"
        )
        
        col1, col2, col3 = st.columns([1, 1, 2])
        with col1:
            analyze_button = st.button("🔍 Analyze Text", type="primary", use_container_width=True, key="analyze_text")
        with col2:
            if st.button("🗑️ Clear", use_container_width=True, key="clear_text"):
                st.rerun()
        
        if analyze_button and text_input.strip():
            with st.spinner("Analyzing text..."):
                result = comprehension_checker(text_input)
                
                st.markdown("### 📊 Analysis Results")
                st.markdown('<div class="result-box">', unsafe_allow_html=True)
                st.code(result, language=None)
                st.markdown('</div>', unsafe_allow_html=True)
        elif analyze_button:
            st.warning("⚠️ Please enter some Chinese text to analyze.")
    
    with tab2:
        st.markdown("### Upload Text Files")
        uploaded_files = st.file_uploader(
            "Choose .txt files containing Chinese text",
            type=['txt'],
            accept_multiple_files=True,
            label_visibility="collapsed"
        )
        
        if uploaded_files:
            analyze_files = st.button("🔍 Analyze Files", type="primary", use_container_width=True, key="analyze_files")
            
            if analyze_files:
                for uploaded_file in uploaded_files:
                    st.markdown(f"### 📄 {uploaded_file.name}")
                    
                    try:
                        # Read file content
                        text = uploaded_file.read().decode('utf-8')
                        
                        if not text.strip():
                            st.warning(f"⚠️ File '{uploaded_file.name}' is empty.")
                            continue
                        
                        with st.spinner(f"Analyzing {uploaded_file.name}..."):
                            result = comprehension_checker(text)
                            
                            st.markdown('<div class="result-box">', unsafe_allow_html=True)
                            st.code(result, language=None)
                            st.markdown('</div>', unsafe_allow_html=True)
                    
                    except Exception as e:
                        st.error(f"❌ Error processing '{uploaded_file.name}': {str(e)}")
                    
                    st.divider()
        else:
            st.info("👆 Upload one or more .txt files to analyze")
    
    # Footer
    st.markdown("---")
    col1, col2, col3 = st.columns(3)
    with col1:
        st.markdown("**Comprehension Levels:**")
        st.markdown("""
        - ⛔ <82%: Too Difficult
        - 🔴 82-87%: Very Challenging
        - 🟡 87-89%: Challenging
        """)
    with col2:
        st.markdown("**Optimal Range:**")
        st.markdown("""
        - 🟢 89-92%: Optimal (i+1)
        - 🔵 92-95%: Comfortable
        - ⚪ >95%: Too Easy
        """)
    with col3:
        st.markdown("**Tips:**")
        st.markdown("""
        - Add HSK words to Known Words
        - Target 89-92% for best learning
        - Proper nouns are auto-excluded
        """)

if __name__ == "__main__":
    # Ensure directories exist
    os.makedirs(KNOWN_WORDS_DIR, exist_ok=True)
    os.makedirs(UNKNOWN_WORDS_DIR, exist_ok=True)
    
    main()