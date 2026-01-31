<script setup>
import { useRouter } from 'vue-router'
const router = useRouter()

// Tech Stack atualizada: Sem Flask e com Imagens Transparentes (SVGs)
const techStack = [
  {
    name: 'Python',
    img: 'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/python/python-original.svg'
  },
  {
    name: 'Vue.js 3',
    img: 'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/vuejs/vuejs-original.svg'
  },
  {
    name: 'MySQL',
    // Versão oficial limpa sem fundo branco
    img: 'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/mysql/mysql-original.svg'
  },
  {
    name: 'Docker',
    img: 'https://cdn.jsdelivr.net/gh/devicons/devicon/icons/docker/docker-original.svg'
  }
]
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-screen text-center px-4 relative overflow-hidden bg-slate-50 dark:bg-slate-900 transition-colors duration-500">
    
    <div class="absolute top-0 left-1/2 -translate-x-1/2 w-full h-[600px] bg-gradient-to-b from-emerald-500/10 via-teal-500/5 to-transparent blur-[120px] pointer-events-none"></div>

    <div class="relative z-10 max-w-5xl flex flex-col items-center">
      
      <h1 class="text-7xl md:text-9xl mb-8 text-slate-900 dark:text-white leading-tight font-serif italic tracking-tight">
        <span>Health</span><span class="text-emerald-600 dark:text-emerald-400">Analytics</span>
      </h1>
      
      <p class="text-slate-600 dark:text-slate-300 text-lg md:text-2xl mb-12 max-w-2xl font-light tracking-wide leading-relaxed">
        Engenharia de dados aplicada à saúde. <br>
        <span class="font-bold text-emerald-600 dark:text-emerald-400">Performance em tempo real.</span>
      </p>

      <button 
        @click="router.push('/dashboard')"
        class="
          group relative inline-flex items-center justify-center 
          px-10 py-4 mb-20
          text-base font-bold text-white 
          bg-emerald-600 rounded-full 
          shadow-lg shadow-emerald-500/30 
          transition-all duration-300 
          hover:bg-emerald-500 hover:scale-105 hover:shadow-emerald-500/50
        "
      >
        <span>Acessar Plataforma</span>
        <svg class="w-5 h-5 ml-2 transition-transform duration-300 group-hover:translate-x-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3" />
        </svg>
      </button>
      
      <div class="w-full animate-fade-in-up">
        <p class="text-xs uppercase tracking-[0.3em] text-slate-400 mb-8 font-bold">Powered By</p>
        
        <div class="flex flex-wrap justify-center gap-6">
          <div 
            v-for="tech in techStack" 
            :key="tech.name"
            class="
              w-16 h-16 p-3
              flex items-center justify-center
              rounded-2xl
              
              /* Fundo base sutil */
              bg-slate-200/50 dark:bg-slate-800/50
              
              /* Efeito Hover: Fica mais claro/iluminado */
              hover:bg-white dark:hover:bg-slate-700
              
              transition-all duration-300 
              cursor-default
              hover:-translate-y-1 hover:shadow-xl dark:shadow-black/30
            "
            :title="tech.name"
          >
            <img 
              :src="tech.img" 
              :alt="tech.name"
              class="w-full h-full object-contain filter drop-shadow-sm"
            />
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}
.animate-fade-in-up {
  animation: fadeInUp 0.8s ease-out forwards;
  animation-delay: 0.2s; 
  opacity: 0; 
}
</style>