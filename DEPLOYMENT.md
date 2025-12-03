# 🚀 Deployment Guide - Streamlit Cloud

This guide will help you deploy Chinese Checker as a public web application using Streamlit Cloud (free).

## Prerequisites

- GitHub account
- This repository pushed to GitHub
- Streamlit Cloud account (free, sign up at [share.streamlit.io](https://share.streamlit.io))

## Step-by-Step Deployment

### 1. Push to GitHub

First, commit and push your changes to GitHub:

```bash
git add .
git commit -m "Add Streamlit web interface"
git push origin streamlit-webapp
```

Then merge to main (or deploy directly from the `streamlit-webapp` branch):

```bash
git checkout main
git merge streamlit-webapp
git push origin main
```

### 2. Deploy to Streamlit Cloud

1. **Sign up/Login** to [share.streamlit.io](https://share.streamlit.io)
   - Use your GitHub account for easy integration

2. **Create New App**
   - Click "New app" button
   - Select your repository: `chelsea6502/chinese-checker`
   - Branch: `main` (or `streamlit-webapp`)
   - Main file path: `app.py`
   - Click "Deploy!"

3. **Wait for Deployment**
   - First deployment takes 5-10 minutes (installing dependencies)
   - Subsequent deployments are faster (~2 minutes)
   - You'll get a public URL like: `https://your-app-name.streamlit.app`

### 3. Configure App Settings (Optional)

In Streamlit Cloud dashboard:

- **Custom subdomain**: Change your app URL
- **Secrets**: Add any API keys (if needed in future)
- **Python version**: Auto-detected from requirements
- **Resources**: Free tier includes 1 GB RAM, 1 CPU

## 🎯 Your App is Live!

Once deployed, your app will be publicly accessible at:
```
https://your-app-name.streamlit.app
```

### Features Available:
- ✅ Upload Chinese text files
- ✅ Paste text directly
- ✅ Manage known/unknown words
- ✅ Real-time comprehension analysis
- ✅ Pinyin and definitions
- ✅ Mobile-friendly interface

## 🔄 Automatic Updates

Streamlit Cloud automatically redeploys when you push to GitHub:

```bash
# Make changes to app.py or other files
git add .
git commit -m "Update feature"
git push origin main
# App automatically redeploys in ~2 minutes
```

## 💡 Tips

1. **First Load**: The app "sleeps" after inactivity. First visit may take 30 seconds to wake up.

2. **Custom Domain**: Upgrade to paid plan for custom domains (e.g., `chinese-checker.com`)

3. **Analytics**: Enable in Streamlit Cloud dashboard to track usage

4. **Monitoring**: Check logs in Streamlit Cloud dashboard for errors

5. **Resource Limits**: Free tier limits:
   - 1 GB RAM
   - 1 CPU core
   - Unlimited public apps
   - Apps sleep after inactivity

## 🐛 Troubleshooting

### App won't start?
- Check logs in Streamlit Cloud dashboard
- Verify `requirements.txt` has all dependencies
- Ensure `packages.txt` includes system dependencies (gcc, g++)

### Slow performance?
- First load is always slower (cold start)
- Consider caching with `@st.cache_data` for heavy operations
- Free tier has resource limits

### Need more resources?
- Upgrade to Streamlit Cloud paid plan
- Or deploy to Railway/Render with more resources

## 🌐 Alternative Deployment Options

If you need more control or resources:

### Railway (Free tier available)
```bash
# Install Railway CLI
npm i -g @railway/cli

# Login and deploy
railway login
railway init
railway up
```

### Render (Free tier available)
1. Connect GitHub repo
2. Select "Web Service"
3. Build command: `pip install -r requirements.txt`
4. Start command: `streamlit run app.py --server.port $PORT`

### Docker + Cloud VM
Use the existing Dockerfile with cloud providers:
- Google Cloud Run
- AWS ECS
- Azure Container Instances

## 📚 Resources

- [Streamlit Documentation](https://docs.streamlit.io)
- [Streamlit Cloud Docs](https://docs.streamlit.io/streamlit-community-cloud)
- [Streamlit Forum](https://discuss.streamlit.io)

## 🎉 Success!

Your Chinese Checker app is now publicly accessible! Share the URL with anyone who wants to analyze Chinese text comprehension.