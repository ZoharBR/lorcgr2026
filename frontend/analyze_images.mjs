import ZAI from 'z-ai-web-dev-sdk';
import fs from 'fs';

async function analyzeImage(imagePath, question) {
  const zai = await ZAI.create();
  
  const imageBuffer = fs.readFileSync(imagePath);
  const base64Image = imageBuffer.toString('base64');
  
  const response = await zai.chat.completions.createVision({
    messages: [
      {
        role: 'user',
        content: [
          { type: 'text', text: question },
          { type: 'image_url', image_url: { url: `data:image/png;base64,${base64Image}` } }
        ]
      }
    ],
    thinking: { type: 'disabled' }
  });

  return response.choices[0]?.message?.content;
}

const images = [
  '/home/z/my-project/upload/pasted_image_1775067328226.png',
  '/home/z/my-project/upload/pasted_image_1775067342183.png',
  '/home/z/my-project/upload/pasted_image_1775067351761.png'
];

console.log('=== Analisando as 3 imagens ===\n');

for (let i = 0; i < images.length; i++) {
  console.log(`\n--- IMAGEM ${i + 1} ---`);
  try {
    const result = await analyzeImage(
      images[i], 
      'Analise esta captura de tela. Descreva todos os erros, problemas ou mensagens de erro que você vê. Liste cada problema encontrado em português do Brasil.'
    );
    console.log(result);
  } catch (error) {
    console.log('Erro ao analisar:', error.message);
  }
}
