from gliner import GLiNER
import re
import torch
import pandas as pd
import os

# Keep in mind that "text" must remain as a string for GLiNER to work.
# Also, entities, entity, labels, label and text are sorf of reserved words for GLiNER.
# There are better ways to use the labels but I had a hellish adventure with this thing already.
# https://huggingface.co/spaces/knowledgator/GLiNER_HandyLab

# Load the model
model = GLiNER.from_pretrained("knowledgator/gliner-multitask-large-v0.5")
access_token = "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"

# Get a list of all files in the current directory
files = os.listdir()
csv_files = [file for file in files if file.endswith('.csv')]
if len(csv_files) >= 1:
    datacsv = pd.read_csv(csv_files[0])
    labels = [
        'modding', 'programming', 'scripting', 'debugging', 'algorithm', 'logic', 'bug', 'patch', 'execute', 'library', 'class', 'object', 'method', 'parameter','argument', 'inheritance', 'iteration', 'recursion', 'conditional', 'loop', 'array', 'list', 'editor', 
        'map', 'mapdata', 'grid', 'lua', 'script', 'table', 'code', 'nil',
        'string', 'boolean', 'function', 'table', 'thread', 'userdata', 'metatable', 'savegame', 'fix', 'global', 'HG'
    ]
    
    # Process the extracted answers
    text = datacsv['Content'].to_string()
    entities = model.predict_entities(text, labels)

# Generate HTML document with extracted answers
html_output = "<!DOCTYPE html><html><head><title>Modding and Programming FAQ</title>"
html_output += "<style>.qa-pair { border: 1px solid #000; padding: 10px; margin-bottom: 20px; }</style></head><body>"

# Create a dictionary to store unique entity texts, their full contexts, and related questions
entity_contexts = {}

# Assume that each 'Content' entry contains a question followed by its answer
# Iterate over each entry in the 'Content' column
for idx, content in enumerate(datacsv['Content']):
    # Split the content into potential question and answer parts
    qa_pairs = re.split(r'\?|\.', str(content))

    # Iterate over the qa_pairs to find and store questions and answers
    for i in range(0, len(qa_pairs) - 1, 2):
        question = qa_pairs[i].strip() + '?'
        answer = qa_pairs[i+1].strip() + '.'

        # Use regex to find the full context that contains the entity text
        for entity in entities:
            if entity['text'].lower() in answer.lower():
                # Store the question and answer pair
                if entity['text'] not in entity_contexts:
                    entity_contexts[entity['text']] = {'questions': [], 'answers': []}
                # Check for repetition in questions
                if question not in entity_contexts[entity['text']]['questions']:
                    entity_contexts[entity['text']]['questions'].append(question)
                    entity_contexts[entity['text']]['answers'].append(answer)

# Add the related questions and answers to the HTML output
for text, data in entity_contexts.items():
    for i in range(len(data['questions'])):
        # Wrap Q&A in div tags for better structure
        html_output += f"<div class='qa-pair'><p><strong>Q:</strong> {data['questions'][i]}</p>"
        html_output += f"<p><strong>A:</strong> {data['answers'][i]}</p></div>"

html_output += "</body></html>"

# Save the HTML document
with open('modding_programming_faq.html', 'w', encoding='utf-8') as file:
    file.write(html_output)
