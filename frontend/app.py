import streamlit as st
import requests
import os

# Backend API URL (using docker service name 'backend')
API_URL = os.getenv("BACKEND_API_URL", "http://backend:8000")

st.set_page_config(page_title="DeepSeek Prompt Runner", page_icon="🤖")

st.title("🤖 DeepSeek Prompt Runner")

@st.cache_data
def get_prompt_ids():
    try:
        response = requests.get(f"{API_URL}/ids")
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        st.error(f"Error connecting to backend: {e}")
        return []

ids = get_prompt_ids()

if not ids:
    st.warning("No prompts found or backend is unreachable.")
else:
    selected_id = st.selectbox("Select a Prompt ID", ids)
    
    if st.button("Get Response"):
        try:
            # 1. Get and Show Prompt Text
            with st.spinner("Fetching prompt details..."):
                 prompt_res = requests.get(f"{API_URL}/prompt/{selected_id}")
                 prompt_res.raise_for_status()
                 prompt_text = prompt_res.json()['prompt_text']
                 st.info(f"**Prompt:** {prompt_text}")

            # 2. Process
            with st.spinner("Fetching response from LLM..."):
                response = requests.post(f"{API_URL}/process/{selected_id}")
                response.raise_for_status()
                result = response.json()
                
                st.success("Response Received:")
                st.write(result["response"])
                
        except requests.exceptions.HTTPError as e:
            st.error(f"API Error: {e.response.text}")
        except Exception as e:
            st.error(f"An error occurred: {e}")
