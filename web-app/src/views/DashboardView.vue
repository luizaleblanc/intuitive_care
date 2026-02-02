<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { Chart as ChartJS, Title, Tooltip, Legend, BarElement, CategoryScale, LinearScale } from 'chart.js'
import { Bar } from 'vue-chartjs'

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend)

const router = useRouter()
const loading = ref(true)
const operadoras = ref([])
const searchQuery = ref('') 
const searchHistory = ref([]) 
const currentPage = ref(1)
const totalPages = ref(1)
const stats = ref({ total_geral: 0, top_ufs: [] })

const chartData = ref({
  labels: [],
  datasets: [{ data: [] }]
})
const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { display: false } }
}

const formatCurrency = (value) => {
  return new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value)
}

// --- INDEXED DB ---
const dbName = 'HealthAnalyticsDB'
const storeName = 'search_history'

const openDB = () => {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(dbName, 1)
    request.onupgradeneeded = (event) => {
      const db = event.target.result
      if (!db.objectStoreNames.contains(storeName)) {
        db.createObjectStore(storeName, { keyPath: 'term' })
      }
    }
    request.onsuccess = (event) => resolve(event.target.result)
    request.onerror = (event) => reject(event.target.error)
  })
}

const loadHistory = async () => {
  try {
    const db = await openDB()
    const tx = db.transaction(storeName, 'readonly')
    const store = tx.objectStore(storeName)
    const request = store.getAll()
    request.onsuccess = () => {
      searchHistory.value = request.result.slice(-5).reverse()
    }
  } catch (err) {
    console.error("Erro ao carregar histórico:", err)
  }
}

const saveSearchTerm = async (term) => {
  if (!term || term.trim().length < 3) return
  try {
    const db = await openDB()
    const tx = db.transaction(storeName, 'readwrite')
    const store = tx.objectStore(storeName)
    store.put({ term: term, timestamp: Date.now() })
    loadHistory()
  } catch (err) {
    console.error("Erro ao salvar histórico:", err)
  }
}

const applyHistorySearch = (term) => {
  searchQuery.value = term
}

const clearSearch = () => {
  searchQuery.value = ''
  currentPage.value = 1
  fetchData()
}

// --- FETCH DATA ---
const fetchData = async () => {
  loading.value = true
  try {
    const resOps = await fetch(`http://localhost:5000/api/operadoras?page=${currentPage.value}&limit=6&search=${searchQuery.value}`)
    const dataOps = await resOps.json()
    operadoras.value = dataOps.data
    totalPages.value = dataOps.total_pages

    if (stats.value.total_geral === 0) {
      const resStats = await fetch('http://localhost:5000/api/estatisticas')
      const dataStats = await resStats.json()
      stats.value = dataStats
      
      chartData.value = {
        labels: dataStats.top_ufs.map(item => item.uf),
        datasets: [{
          label: 'Despesas por UF',
          backgroundColor: '#10b981',
          data: dataStats.top_ufs.map(item => item.total),
          borderRadius: 6
        }]
      }
    }
  } catch (error) {
    console.error("Erro na API:", error)
  } finally {
    loading.value = false
  }
}

const debounceSearch = (() => {
  let timer
  return () => {
    clearTimeout(timer)
    timer = setTimeout(() => {
      currentPage.value = 1
      if (searchQuery.value.length >= 3) {
        saveSearchTerm(searchQuery.value)
      }
      fetchData()
    }, 800)
  }
})()

watch(searchQuery, debounceSearch)
watch(currentPage, fetchData)

onMounted(() => {
  searchQuery.value = '' 
  loadHistory()
  fetchData()
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
    </header>

    <div v-if="loading && !operadoras.length" class="animate-pulse space-y-8">
       <div class="h-96 bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
    </div>

    <div v-else class="space-y-8">
      <div class="bg-white dark:bg-slate-800 p-6 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700/50">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">Filtrar Operadoras</label>
        <div class="relative">
          <input 
            v-model="searchQuery" 
            type="text" 
            autocomplete="off" 
            placeholder="Digite o CNPJ ou Razão Social..." 
            class="w-full bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-4 py-3 focus:ring-2 focus:ring-brand-500 outline-none dark:text-white transition-all pl-10"
          >
          <span class="absolute left-3 top-3.5 text-slate-400">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
          </span>
          <button 
            v-if="searchQuery" 
            @click="clearSearch"
            class="absolute right-3 top-3 text-slate-400 hover:text-red-500"
          >
            ✕
          </button>
        </div>

        <div v-if="searchHistory.length > 0 && !searchQuery" class="mt-4 animate-fade-in">
          <p class="text-xs uppercase text-slate-400 font-bold tracking-wider mb-2">Últimas pesquisas</p>
          <div class="flex flex-wrap gap-2">
            <button 
              v-for="item in searchHistory" 
              :key="item.term"
              @click="applyHistorySearch(item.term)"
              class="text-xs bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 px-3 py-1 rounded-full hover:bg-brand-100 hover:text-brand-600 border border-transparent hover:border-brand-200 transition-all"
            >
              {{ item.term }}
            </button>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="lg:col-span-2 bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700/50 overflow-hidden flex flex-col">
          <div class="p-6 border-b border-slate-100 dark:border-slate-700 flex justify-between items-center">
            <h3 class="font-bold text-lg text-slate-800 dark:text-white">Resultados</h3>
            <span class="text-xs font-mono text-slate-400 bg-slate-100 dark:bg-slate-700 px-2 py-1 rounded">Pág {{ currentPage }}/{{ totalPages }}</span>
          </div>
          <div class="flex-1 overflow-x-auto">
            <table class="w-full text-left text-sm text-slate-600 dark:text-slate-300">
              <thead class="bg-slate-50 dark:bg-slate-900/50 uppercase text-xs font-semibold">
                <tr>
                  <th class="px-6 py-4">Registro ANS</th>
                  <th class="px-6 py-4">CNPJ</th>
                  <th class="px-6 py-4">Razão Social</th>
                  <th class="px-6 py-4">UF</th>
                  <th class="px-6 py-4 text-right">Ação</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                <tr v-for="op in operadoras" :key="op.reg_ans" class="group hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors">
                  <td class="px-6 py-4 font-mono text-xs">{{ op.reg_ans }}</td>
                  <td class="px-6 py-4 font-mono text-xs">{{ op.cnpj }}</td>
                  <td class="px-6 py-4 font-medium text-slate-900 dark:text-white group-hover:text-brand-600 transition-colors">{{ op.razao_social }}</td>
                  <td class="px-6 py-4">
                    <span :class="{'bg-red-100 text-red-600': op.uf === 'NI', 'bg-slate-100 dark:bg-slate-700': op.uf !== 'NI'}" class="px-2 py-1 rounded text-xs font-bold">
                      {{ op.uf }}
                    </span>
                  </td>
                  <td class="px-6 py-4 text-right">
                    <button 
                      @click="router.push(`/operadora/${op.cnpj}`)" 
                      class="bg-brand-600 text-white font-semibold text-xs border border-brand-600 px-3 py-1.5 rounded-lg transition-all hover:bg-white hover:text-brand-600"
                    >
                      Detalhes
                    </button>
                  </td>
                </tr>
                <tr v-if="operadoras.length === 0">
                   <td colspan="5" class="px-6 py-12 text-center text-slate-400">
                     Nenhuma operadora encontrada para "{{ searchQuery }}".
                   </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="p-4 border-t border-slate-100 dark:border-slate-700 flex justify-between items-center gap-2">
            <button :disabled="currentPage === 1" @click="currentPage--" class="px-4 py-2 text-sm font-medium bg-slate-100 dark:bg-slate-700 rounded-lg disabled:opacity-50 hover:bg-slate-200 dark:hover:bg-slate-600 transition-colors">Anterior</button>
            <button :disabled="currentPage === totalPages" @click="currentPage++" class="px-4 py-2 text-sm font-medium bg-slate-100 dark:bg-slate-700 rounded-lg disabled:opacity-50 hover:bg-slate-200 dark:hover:bg-slate-600 transition-colors">Próxima</button>
          </div>
        </div>

        <div class="space-y-6">
          <div class="bg-gradient-to-br from-brand-600 to-brand-700 rounded-2xl p-6 text-white shadow-xl shadow-brand-500/20 relative overflow-hidden">
             <div class="absolute -right-6 -top-6 w-32 h-32 bg-white/10 rounded-full blur-3xl"></div>
            <p class="text-brand-100 font-medium mb-1 text-sm uppercase tracking-wider">Total Geral de Despesas</p>
            <p class="text-3xl font-bold">{{ formatCurrency(stats.total_geral) }}</p>
          </div>

          <div class="bg-white dark:bg-slate-800 rounded-2xl p-6 shadow-sm border border-slate-100 dark:border-slate-700/50 h-80 flex flex-col">
            <h3 class="font-bold text-sm uppercase tracking-wider mb-4 text-slate-500 dark:text-slate-400">Top 5 Estados (Gastos)</h3>
            <div class="flex-1 relative">
              <Bar :data="chartData" :options="chartOptions" />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>