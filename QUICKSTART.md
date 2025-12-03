# 🚀 Quick Start Guide

## Local Development

### 1. Install Dependencies

```bash
pip install -r requirements.txt
python -m spacy download zh_core_web_sm
```

### 2. Run the Web App

```bash
streamlit run app.py
```

The app will open automatically at `http://localhost:8501`

## 🌐 Deploy to Streamlit Cloud (Free)

### Prerequisites
- GitHub account
- Push this branch to GitHub

### Steps

1. **Push to GitHub**
   ```bash
   git add .
   git commit -m "Add Streamlit web interface"
   git push origin streamlit-webapp
   ```

2. **Deploy**
   - Go to [share.streamlit.io](https://share.streamlit.io)
   - Sign in with GitHub
   - Click "New app"
   - Select your repo: `chelsea6502/chinese-checker`
   - Branch: `streamlit-webapp`
   - Main file: `app.py`
   - Click "Deploy!"

3. **Done!**
   - Your app will be live at: `https://your-app-name.streamlit.app`
   - First deployment takes ~5-10 minutes
   - Auto-redeploys on every push to GitHub

## 📱 Using the App

### Analyze Text
1. **Paste Text**: Go to "Analyze Text" tab, paste Chinese text
2. **Upload Files**: Go to "Upload Files" tab, upload `.txt` files
3. Click "Analyze" to see comprehension results

### Manage Words
1. Click "Manage Known Words" in sidebar
2. Add words you know (one per line)
3. Click "Save Known"
4. Repeat for "Manage Unknown Words" if needed

### Interpret Results
- **89-92%** = Optimal for learning (i+1 level)
- **<89%** = Too difficult
- **>92%** = Too easy

## 🔧 Troubleshooting

### App won't start locally?
```bash
# Reinstall dependencies
pip install -r requirements.txt --force-reinstall
python -m spacy download zh_core_web_sm
```

### Streamlit Cloud deployment fails?
- Check logs in Streamlit Cloud dashboard
- Verify all files are committed and pushed
- Ensure `packages.txt` and `requirements.txt` are present

## 📚 More Information

- **Full Deployment Guide**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- **Web App Features**: See [README_WEB.md](README_WEB.md)
- **CLI Version**: See [README.md](README.md)

## 🎉 Success!

Your Chinese Checker web app is ready to use! Share the URL with anyone who wants to analyze Chinese text comprehension.