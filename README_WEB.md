# 🌐 Chinese Checker - Web Application

A web-based tool for analyzing Chinese text comprehension based on your known words.

## 🚀 Quick Start

### Run Locally

```bash
# Install dependencies
pip install -r requirements.txt
python -m spacy download zh_core_web_sm

# Run the web app
streamlit run app.py
```

The app will open in your browser at `http://localhost:8501`

### Run with Docker

```bash
# Build and run
docker build -t chinese-checker-web .
docker run -p 8501:8501 chinese-checker-web
```

Visit `http://localhost:8501` in your browser.

## 📱 Features

### Text Analysis
- **Paste Text**: Directly paste Chinese text for instant analysis
- **Upload Files**: Batch analyze multiple `.txt` files
- **Real-time Results**: Get comprehension percentage and unknown words

### Word Management
- **Known Words**: Add HSK vocabulary or custom word lists
- **Unknown Words**: Mark compound words that shouldn't count as known
- **Persistent Storage**: Your word lists are saved between sessions

### Smart Analysis
- **Proper Noun Detection**: Automatically excludes names and places
- **Pinyin Display**: Shows pronunciation for unknown words
- **Dictionary Definitions**: Instant offline definitions from CC-CEDICT
- **Comprehension Levels**: Color-coded difficulty assessment

## 🎯 Comprehension Levels

- ⛔ **<82%**: Too Difficult
- 🔴 **82-87%**: Very Challenging  
- 🟡 **87-89%**: Challenging
- 🟢 **89-92%**: Optimal (i+1) - Best for learning!
- 🔵 **92-95%**: Comfortable
- ⚪ **>95%**: Too Easy

## 📖 Usage Tips

1. **Add Your Known Words**
   - Click "Manage Known Words" in the sidebar
   - Add HSK vocabulary or words you've learned
   - Save to persist across sessions

2. **Analyze Text**
   - Paste Chinese text or upload `.txt` files
   - Click "Analyze" to see results
   - Target 89-92% comprehension for optimal learning

3. **Review Unknown Words**
   - See frequency counts for each unknown word
   - Pinyin helps with pronunciation
   - Definitions help understand context

## 🔧 Technical Details

### Built With
- **Streamlit**: Web framework
- **pkuseg**: Chinese word segmentation (~97% accuracy)
- **spaCy**: Named entity recognition
- **pypinyin**: Pinyin conversion
- **CC-CEDICT**: Chinese-English dictionary

### Architecture
- Frontend: Streamlit web interface
- Backend: Python with NLP libraries
- Storage: Local file system for word lists
- Dictionary: Offline CC-CEDICT lookup

## 📦 Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions to:
- Streamlit Cloud (free, recommended)
- Railway
- Render
- Docker + Cloud VM

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- Additional dictionary sources
- Export analysis results
- User authentication
- Cloud storage for word lists
- Mobile app version

## 📄 License

MIT License - see [LICENSE](LICENSE) for details

## 🙏 Acknowledgments

Based on [Destaq/chinese-comprehension](https://github.com/Destaq/chinese-comprehension)

---

**Ready to deploy?** Check out [DEPLOYMENT.md](DEPLOYMENT.md) for step-by-step instructions!