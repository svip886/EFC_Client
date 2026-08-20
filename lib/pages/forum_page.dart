import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/ecfc_models.dart';
import '../providers/service_providers.dart';
import '../widgets/post_card.dart';

/// E院广场：分区筛选 + 排序 + 帖子列表，风格参考 FluxDO topics_page。
class ForumPage extends ConsumerStatefulWidget {
  const ForumPage({super.key});

  @override
  ConsumerState<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends ConsumerState<ForumPage> {
  final _scrollController = ScrollController();
  final List<EcfcPost> _posts = [];
  List<EcfcBoard> _boards = const [];
  String? _selectedBoardSlug;
  String _sort = 'latest';
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _initialLoading = true;
  String? _error;

  static const _sortOptions = [
    ('latest', '最新'),
    ('replies', '最新回复'),
    ('hot', '最热'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 200 &&
        !_loading &&
        _page < _totalPages) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
        _initialLoading = _posts.isEmpty;
      }
    });

    final nextPage = reset ? 1 : _page + 1;
    try {
      final result = await ref.read(forumServiceProvider).feed(
            sort: _sort,
            page: nextPage,
            board: _selectedBoardSlug,
          );
      setState(() {
        if (reset) {
          _posts
            ..clear()
            ..addAll(result.posts);
          _boards = result.boards;
        } else {
          _posts.addAll(result.posts);
        }
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '加载失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E院广场'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildBoardChips()),
            SliverToBoxAdapter(child: _buildSortChips()),
            if (_initialLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _posts.isEmpty)
              SliverFillRemaining(child: _buildError())
            else
              SliverList.builder(
                itemCount: _posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    return _buildFooter();
                  }
                  return PostCard(post: _posts[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardChips() {
    if (_boards.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _boardChip(null, '全部'),
          for (final b in _boards) _boardChip(b.slug, '${b.name}${b.postCount}'),
        ],
      ),
    );
  }

  Widget _boardChip(String? slug, String label) {
    final selected = _selectedBoardSlug == slug;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedBoardSlug = slug);
          _load(reset: true);
        },
      ),
    );
  }

  Widget _buildSortChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final opt in _sortOptions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(opt.$2),
                selected: _sort == opt.$1,
                onSelected: (_) {
                  setState(() => _sort = opt.$1);
                  _load(reset: true);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_page >= _totalPages) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('没有更多了')),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error ?? '加载失败'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _load(reset: true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
