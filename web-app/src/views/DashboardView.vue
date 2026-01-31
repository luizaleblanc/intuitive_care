<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const loading = ref(true)

onMounted(() => {
  setTimeout(() => loading.value = false, 1000)
})
</script>

<template>
  <div class="container mx-auto px-6 py-10 max-w-7xl">
    <header class="flex justify-between items-end mb-12">
      <div>
        <button @click="router.push('/')" class="text-sm font-semibold text-slate-400 hover:text-brand-500 mb-2 flex items-center gap-1 transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" /></svg>
          Voltar para Home
        </button>
        <h2 class="text-3xl font-bold text-slate-800 dark:text-white">Painel Geral</h2>
      </div>
      <div class="hidden md:block text-right">
        <p class="text-sm text-slate-500 dark:text-slate-400">Dados consolidados</p>
        <p class="font-mono text-brand-600 dark:text-brand-400 font-bold">FONTE: ANS 2024-2025</p>
      </div>
    </header>

    <div v-if="loading" class="animate-pulse space-y-8">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="h-32 bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
        <div class="h-32 bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
        <div class="h-32 bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
      </div>
      <div class="h-96 bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
    </div>

    <div v-else class="space-y-8">
      <div class="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700/50">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">Filtrar Operadoras</label>
        <div class="flex gap-4">
          <input type="text" placeholder="Digite o CNPJ ou Razão Social..." class="flex-1 bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-4 py-3 focus:ring-2 focus:ring-brand-500 focus:border-transparent outline-none transition-all dark:text-white">
          <button class="bg-brand-600 text-white px-8 py-3 rounded-xl font-semibold hover:bg-brand-500 transition-colors shadow-lg shadow-brand-500/20">Buscar</button>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="lg:col-span-2 bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700/50 overflow-hidden">
          <div class="p-6 border-b border-slate-100 dark:border-slate-700">
            <h3 class="font-bold text-lg">Listagem de Operadoras</h3>
          </div>
          <div class="p-6 text-center text-slate-400 py-20">
            Tabela de dados será carregada aqui...
          </div>
        </div>

        <div class="space-y-6">
          <div class="bg-brand-600 rounded-2xl p-6 text-white shadow-xl shadow-brand-500/20 relative overflow-hidden">
            <div class="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-10 -mt-10"></div>
            <p class="text-brand-100 font-medium mb-1">Total de Despesas</p>
            <p class="text-3xl font-bold">R$ --,--</p>
          </div>

          <div class="bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-100 dark:border-slate-700/50">
            <h3 class="font-bold text-lg mb-4">Top Estados</h3>
            <div class="h-40 flex items-center justify-center text-slate-400 text-sm">
              Gráfico Chart.js aqui
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>